//
//  Copyright (C) 2021 Twilio, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Alamofire
import Foundation

class API {
    static var shared = API()
    private let session = Session()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let url = <#BACKEND_URL#>

    init() {
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    func request<Request: APIRequest>(
        _ request: Request,
        completion: ((Result<Request.Response, Error>) -> Void)? = nil
    ) {
        session.request(
            "\(url)/\(request.path)",
            method: .post, // Twilio Functions does not care about method
            parameters: request.parameters,
            encoder: JSONParameterEncoder(encoder: jsonEncoder),
            headers: nil
        ).validate().responseDecodable(of: request.responseType, decoder: jsonDecoder) { [weak self] response in
            guard let self = self else { return }
            
            switch response.result {
            case let .success(response):
                completion?(.success(response))
            case let .failure(error):
                guard
                    let data = response.data,
                    let errorResponse = try? self.jsonDecoder.decode(APIErrorResponse.self, from: data)
                else {
                    completion?(.failure(error))
                    return
                }

                completion?(.failure(LiveStreamError.other(message: errorResponse.error.explanation)))
            }
        }
    }
}
