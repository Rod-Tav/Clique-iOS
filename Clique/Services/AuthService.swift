import SwiftUI
import FirebaseAuth
import OpenAPIURLSession
import Mixpanel

enum AppViewType {
    case splash, auth, main
}

@Observable final class AuthService {
    @AppStorage("hasMixpanelProfile") static var hasMixpanelProfile: Bool = false
    
    var appViewType: AppViewType = .splash
    
    private var splash: Bool = true
    
    private var verificationID: String?
    
    private var userStore: UserStore
    
    init(_ userStore: UserStore) {
        self.userStore = userStore
    }
        
    func loadUserData() async {
        print("loading user data")
        let currentUser = Auth.auth().currentUser
        guard currentUser?.uid != nil else {
            appViewType = .auth
            return
        } // no user session which means no user data --> signup/login
        
//        try? await print(currentUser?.getIDTokenResult().token)
        
        do {
            try await UserService.fetchCurrentUser(userStore: userStore)
            
            await MainActor.run {
                appViewType = .main
            }
            
            if let user = await userStore.currentUser {
                if !AuthService.hasMixpanelProfile {
                    Mixpanel.mainInstance().identify(distinctId: user.id)
                    
                    Mixpanel.mainInstance().people.set(properties: [
                        "$name": user.fullname,
                        "$number": user.number,
                        "$id": user.id,
                        "$visibility": user.isPrivate
                    ])
                    
                    AuthService.hasMixpanelProfile = true
                }
                
                track("App Opens")
            }
        } catch { // usersession, no user data --> signup/login (started signup but didn't finish)
            appViewType = .auth
            return
        }
        
        // usersession, user data main view
    }
    
    func startAuth(phoneNumber: String, completion: @escaping (Bool) -> Void) {
        print("starting auth")
        
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            guard let verificationID, error == nil else {
                print("auth failed - verificationID: \(verificationID ?? "nil"), error: \(error?.localizedDescription ?? "no error description")")
                completion(false)
                return
            }
            print("passed guard")
            self?.verificationID = verificationID
            completion(true)
        }
    }
    
    // returns success, doesUserExist
    func verifyCode(smsCode: String, userStore: UserStore, completion: @escaping (Bool, Bool) -> Void) {
        guard let verificationID else {
            completion(false, false)
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: smsCode
        )
        
        Auth.auth().signIn(with: credential) { result, error in
            if let error {
                print("DEBUG: Failed to sign in with error: \(error.localizedDescription)")
                completion(false, false)
                return
            }
            
            guard let user = result?.user else {
                completion(false, false)
                return
            }
            
            user.getIDToken { token, error in
                if let error = error {
                    print("DEBUG: Failed to fetch ID token with error: \(error.localizedDescription)")
                    completion(false, false)
                } else {
                    Task {
                        do {
                            try await UserService.fetchCurrentUser(userStore: userStore)
                            
                            self.appViewType = .main
//                            self.userSession = user
                            // logging in
                            completion(true, true)
                        } catch(let error) {
                            if let error = error as? ServiceError, error == ServiceError.userDoesNotExist {
                                // signing up
                                completion(true, false)
                            } else {
                                completion(false, false)
                            }
                        }
                    }
                }
            }
        }
    }
    
//    func signout() throws {
//        Task {
//            await MainActor.run {
////                self.userSession = nil
//                userStore.currentUserId = nil
//                self.appViewType = .auth
//            }
//        }
//    }
}
