# API Services

This Swift Package makes setting up a network service easy and send requests through async/await. 

## Overview

When using this framework, you will want to configure it when your target launches by assigned desired values to `Configuration`. After that, you can create specialized instances of APIServices for relative feature paths or use a static methods to directly generate request objects and send them.

## Getting Started

An API Service can be represented through any object that adheres to the `APIServiceType` protocol. The open class `APIService` is already provided for you and you can choose to either use this directly or subclass it. 

```swift
let userService = APIService(serviceName: "Users", rootURLString: "https://www.mysite.com/service")
let userParams: JSON = ["id": 8675309]
let userData: Data = try await userService.performRequest("GetDetails", httpMethod: .get, parameters: userParams)
return userData
```

You can also use `APIService` to access the static functions provided to any `APIServiceType`.

```swift
guard let url = URL(string: "https://www.mysite.com/service/Users/GetDetails"),
    let parameterData = APIService.requestBody(forParameters: userParams) else { return }

let getUserRequest = await APIService.request(url: url, parameterData: parameterData)
let userData: Data = try await APIService.performRequest(getUserRequest)
return userData
```

## Global Configuration

Most of the time the majority of requests your app sends are to the same API. This means you'll want to apply the same standards to any service you use. Setting properties on `Configuration` when your app launches will inject your preferences into may services. You can provide the common root path of your requets with `Configuration.defaultServerRootPath`. If you want to do more than log errors to your console, such as send them off to Crashlytics, you can provide your own `Configuration.errorLogger`. If your endpoints use a certain date encoding format, you can provide it through `Configuration.dateEncodingStrategy` and `Configuration.dateDecodingStrategy`.

```swift
extension AppDelegate {

    func injectDependencies() {
        APIServices.Configuration.defaultServerRootPath = "https://www.mysite.com/api"
        APIServices.Configuration.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.custom(myDateDecoder(date:))
        APIServices.Configuration.dateEncodingStrategy = JSONDecoder.DateEncodingStrategy.custom(myDateEncoder(date:))
        APIServices.Configuration.errorLogger = MyErrorLogger()
    }
}
```

## Maintaining Authority

Some endpoints may require authorization, returning a 401 when a request does not include the right token in its header. By providing a method of adding necessary headers to any request, `Configuration.addHeadersToRequest` will pass this functionality along to any services you use.

```swift
APIServices.Configuration.addHeadersToRequest = {
    var authRequest = $0
    
    if let token = await getAuthToken() {
        authRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    return authRequest
}
```
> [!TIP]
> You may have noticed in our `APISerivce` static function example we had to await the generation of a request. This is because the injection of proper headers is built into the creation of requests, as services like OAuth may require us to wait of the latest token to be fetched.

### Second Chances

Should a request return with a 401 error code, you'll probably want to do something about it. With the help of `Configuration.unauthorizedResponseHandler` you can give your user a chance to sign in again and retry the request or sign out. A mutatable boolean is passed in to be updated for tracking the progress of the response. While `true`, any subsequent requests will immediately throw the error `APIError.awaitingAuthorization`. Should your provided handler resolve without issue, it can have the offending request retry by returning `true`.  

```swift
/// Give the user a chance to sign in again when a network request returns a 401 (Unauthorized) error code.
/// - Parameter isAwaitingAuthorization: A mutatable boolean to be updated for tracking the progress of the response.
/// - Returns: Indicates whether or not to retry the request.
@MainActor
func promptToAuthorize(isAwaitingAuthorization: inout Bool) async throws -> Bool {
    isAwaitingAuthorization = true

    let presenter = appCoordinator.presentationViewController()

    do {
        // Get rid of the bad authState
        try? await AuthService.shared.signOut()

        // Wait until the sign in modal has presented before showing the error toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AlertHelper.showProblem("Something went wrong. Please sign in to continue.")
        }
        try await AuthService.shared.signIn(presenter: presenter)
        isAwaitingAuthorization = false
        
        // Retry the unauthorized request
        return true

    } catch {
        isAwaitingAuthorization = false

        // User did not sign back in so we must reset the UI.
        try? await UserSessionService.default().signOut()
        appCoordinator.resetToHomeView()
        throw RegisterUserError.userCanceled
    }
}

Netwokring.Configuration.unauthorizedResponseHandler = promptToAuthorize
```

## Mocking Requests

When it comes to testing, you'll want to avoid sending real network requests and keep your response data consistent. To do this, you can provide a folder of JSON files that mimic your network responses. The subfolders and file names should mirror the relative paths of your requests. For example, your mock response for getting a user's details would be found in your MockJSON folder as such: _MockJSON/Users/GetDetails.json_

> [!IMPORTANT]
> To indicate where your sample responses are located, you will need to add "mock_data_directory" to your Info.plist (ex. `${PROJECT_DIR}/MockJSON/`)

While developing a new feature, you can set a specific service to use mock data by setting `shouldUseMockData` to `true`. By default, this value is whatever you have set `Configuration.shouldUseMockData` to be. This means you can add a switch to your _secret_ debug menu within your app, allowing QA to universally use mock data and continue their design audit of your newest feature even with the servers are down.

> [!NOTE]
> You likely don't want these JSON files included in your next release candidate. You can exclude these files by declaring them in your project's Build Settings -> Build Options -> Excluded Source File Names (ex. `$(SRCROOT)/MockJSON/*`)

## Caching Responses

If you don't feel like manually importing a JSON file for every network request your app makes, you can have these files generated for you automatically. This can be done within a specific service through `shouldCacheResponses` or globally with `Configuration.shouldCacheResponses`.

> [!WARNING]
> This is only for engineers to use when running a debug build from Xcode, as it makes use of your project file structure on your local machine.

## Testing

This framework provides a singleton of `BuildConfig` for determining whether the running build is for debugging or release. With a little extra effort, you can also have cases for testing. 

To make sure your current `BuildConfig` is `BuildConfig.unitTest` when running your unit tests, you will need to add the argument "UNIT-TESTING" to your build scheme(s).

![An example of providing an arguement when testing.](/Sources/APIServices/APIServices.docc/Resources/unit-test-setup.png)

For the case of `BuildConfig.uiTest` we can't use the scheme argument because UI Automation uses the Run scheme, same as running the app normally. Instead, we can provide it in our code before launching the app.

```swift
func testLogin_NewUser() throws {
    let app = XCUIApplication()
    app.launchArguments += ["UI-TESTING"]
    app.launch()
    
    // Test your interface
}
```

This will allow you provide logic in your main target to execute (or not) only when running tests.

```swift
switch BuildConfig.current {
case .release:
    AnalyticsManager.shared.setup(for: .release)
case .debug:
    AnalyticsManager.shared.setup(for: .staging)
case .unitTest, .uiTest:
    AnalyticsManager.shared.disable()
}
```
_OR_
```swift
if !BuildConfig.isTesting {
    AnalyticsManager.shared.setup()
}
```

> [!TIP]
> By default, the global configuration for `Configuration.shouldUseMockData` is `true` when `BuildConfig.isTesting`. This means your unit tests will automatically used captured responses out-of-box, assuming you have provided the "UNIT-TESTING" argument and the JSON files are made available.
