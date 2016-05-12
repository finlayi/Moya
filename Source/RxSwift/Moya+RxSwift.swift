import Foundation
import RxSwift
import Result

/// Subclass of MoyaProvider that returns Observable instances when requests are made. Much better than using completion closures.
public class RxMoyaProvider<Target where Target: TargetType>: MoyaProvider<Target> {
    /// Initializes a reactive provider.
    override public init(endpointClosure: EndpointClosure = MoyaProvider.DefaultEndpointMapping,
        requestClosure: RequestClosure = MoyaProvider.DefaultRequestMapping,
        stubClosure: StubClosure = MoyaProvider.NeverStub,
        manager: Manager = RxMoyaProvider<Target>.DefaultAlamofireManager(),
        plugins: [PluginType] = []) {
            super.init(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, manager: manager, plugins: plugins)
    }

    /// Designated request-making method.
    public func request(token: Target) -> Observable<Response> {

        // Creates an observable that starts a request each time it's subscribed to.
        return Observable.create { [weak self] observer in
            let cancellableToken = self?.request(token) { result in
                switch result {
                case let .Success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                    break
                case let .Failure(error):
                    observer.onError(error)
                }
            }

            return AnonymousDisposable {
                cancellableToken?.cancel()
            }
        }
    }
}

public extension RxMoyaProvider where Target:MultipartTargetType {
    public func request(token: Target) -> (progress:Observable<Progress>, response:Observable<Response>) {
        // Progress should never rise and error
        let progressSubject = PublishSubject<Progress>()
        let progressBlock = {(progress:Progress) -> Void in
            progressSubject.onNext(progress)
            if progress.completed {
                progressSubject.onCompleted()
            }
        }
        
        let response:Observable<Response> = Observable.create { [weak self] observer in
            let cancellableToken = self?.request(token, progress:progressBlock){ result in
                switch result {
                case let .Success(response):
                    observer.onNext(response)
                    observer.onCompleted()
                    progressSubject.onCompleted()
                    break
                case let .Failure(error):
                    observer.onError(error)
                    progressSubject.onCompleted()
                }
            }
            
            return AnonymousDisposable {
                cancellableToken?.cancel()
            }
        }
        
        return (progress:progressSubject, response: response)
    }
}
