//
//  DualPaneView.swift
//  MacCommander
//

import SwiftUI

struct DualPaneView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        HSplitView {
            FilePanelView(app: app, side: .left)
            FilePanelView(app: app, side: .right)
        }
    }
}
