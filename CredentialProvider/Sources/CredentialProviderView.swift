//
//  CredentialProviderView.swift
//  LocalPasskeyManager
//
//  Created by Koji Murata on 2026/01/27.
//

import SwiftUI

@Observable
class CredentialProviderViewModel {
    enum Status {
        case loading
        case failure
    }

    var message: String?
    var status: Status = .loading
}

struct CredentialProviderView: View {
    var viewModel: CredentialProviderViewModel
    let close: () -> Void
    
    var body: some View {
        VStack {
            if let message = viewModel.message {
                Text(message)
            }
            
            switch viewModel.status {
            case .loading:
                ProgressView()
            case .failure:
                Button("OK", role: .close, action: close)
                    .buttonStyle(.borderedProminent)
                    .clipShape(.capsule)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .fixedSize()
    }
}
