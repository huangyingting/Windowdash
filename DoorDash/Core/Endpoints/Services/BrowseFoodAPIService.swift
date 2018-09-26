//
//  BrowseFoodAPIService.swift
//  DoorDash
//
//  Created by Marvin Zhan on 2018-09-23.
//  Copyright © 2018 Monster. All rights reserved.
//

import Moya
import SwiftyJSON
import Alamofire

final public class BrowseFoodAPIServiceError: DefaultError {

}

final class FetchAllRestaurantRequestModel {
    let limit: Int
    let nextOffset: Int
    let latitude: Double
    let longitude: Double
    let sortOption: BrowseFoodSortOptionType?

    init(limit: Int = 50,
         nextOffset: Int,
         latitude: Double,
         longitude: Double,
         sortOption: BrowseFoodSortOptionType?) {
        self.limit = limit
        self.nextOffset = nextOffset
        self.latitude = latitude
        self.longitude = longitude
        self.sortOption = sortOption
    }

    func convertToQueryParams() -> [String: Any] {
        var result: [String: Any] = [:]
        result["extra"] = "stores.business_id"
        result["limit"] = String(limit)
        result["offset"] = String(nextOffset)
        if let sortOption = self.sortOption {
            result["sort_options"] = "true"
            result["order_type"] = sortOption.rawValue
        }
        result["lat"] = String(latitude)
        result["lng"] = String(longitude)
        return result
    }
}

final class BrowseFoodAPIService: DoorDashAPIService {

    var error: DoorDashAPIService.HTTPURLResponseErrorConverter {
        return { response, responseBody in
            return UserAPIError(code: response.statusCode, responseBody: responseBody)
        }
    }

    let browseFoodAPIProvider = MoyaProvider<BrowseFoodAPITarget>(manager: SessionManager.authSession)

    enum BrowseFoodAPITarget: TargetType {
        case fetchFrontEndLayout(latitude: Double, longitude: Double)
        case fetchAllRestaurants(request: FetchAllRestaurantRequestModel)

        var baseURL: URL {
            return ApplicationEnvironment.current.networkConfig.hostURL
        }

        var path: String {
            switch self {
            case .fetchAllRestaurants:
                return "v2/store_search/"
            case .fetchFrontEndLayout:
                return "v1/frontend_layouts/consumer_homepage/"
            }
        }

        var method: Moya.Method {
            switch self {
            case .fetchAllRestaurants, .fetchFrontEndLayout:
                return .get
            }
        }

        var task: Task {
            switch self {
            case .fetchAllRestaurants(let model):
                let params = model.convertToQueryParams()
                return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
            case .fetchFrontEndLayout(let latitude, let longitude):
                var params: [String: Any] = [:]
                params["lat"] = String(latitude)
                params["lng"] = String(longitude)
                params["show_nested"] = String(true)
                return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
            }
        }

        var sampleData: Data {
            switch self {
            case .fetchAllRestaurants, .fetchFrontEndLayout:
                return Data()
            }
        }

        var headers: [String : String]? {
            return nil
        }
    }
}

extension BrowseFoodAPIService {
    func fetchAllRestaurants(model: FetchAllRestaurantRequestModel,
                             completion: @escaping (Error?) -> ()) {
    }

    func fetchPageLayout(userLat: Double,
                         userLng: Double,
                         completion: @escaping (BrowseFoodMainView?, Error?) -> ()) {
        browseFoodAPIProvider.request(.fetchFrontEndLayout(latitude: userLat, longitude: userLng)) { (result) in
            switch result {
            case .success(let response):
                guard response.statusCode == 200,
                    let dataJSON = try? JSON(data: response.data) else {
                    let error = self.handleError(response: response)
                    completion(nil, error)
                    return
                }
                guard let jsonArray = dataJSON.array, jsonArray.count > 0 else {
                    print("No data? WTF?")
                    completion(nil, DefaultError.unknown)
                    return
                }
                let mainView = self.parsePageLayout(jsonArray: jsonArray)
                completion(mainView, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    func parsePageLayout(jsonArray: [JSON]) -> BrowseFoodMainView {
        var cuisineCategories: [BrowseFoodCuisineCategory] = []
        var storeSecitons: [BrowseFoodSectionStore] = []
        for json in jsonArray {
            guard let type = BrowseFoodMainViewSectionType(
                rawValue: json["name"].string ?? "") else {
                    continue
            }
            let dataJSON = json["data"]
            if type == .cuisineCarousel, let categoryJSONs = dataJSON["categories"].array {
                for categoryJSON in categoryJSONs {
                    if let cusineCategory = try? JSONDecoder().decode(
                        BrowseFoodCuisineCategory.self, from: categoryJSON.rawData()
                        ) {
                        cuisineCategories.append(cusineCategory)
                    }
                }
                continue
            }
            if let storeJSONs = dataJSON["stores"].array,
                let title = dataJSON["title"].string {
                var stores: [Store] = []
                for storeJSON in storeJSONs {
                    do {
                        let store = try JSONDecoder().decode(Store.self, from: storeJSON.rawData())
                        stores.append(store)
                    } catch let error {
                        print(error)
                        continue
                    }
                }
                storeSecitons.append(
                    BrowseFoodSectionStore(title: title, type: type, stores: stores)
                )
            }
        }
        let mainView = BrowseFoodMainView(
            cuisineCategories: cuisineCategories, storeSections: storeSecitons
        )
        return mainView
    }
}


