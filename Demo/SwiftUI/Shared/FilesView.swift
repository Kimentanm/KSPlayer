//
//  FilesView.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/3.
//

import KSPlayer
import SwiftUI

struct FilesView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \M3UModel.name, ascending: true)]
    )
    private var m3uModels: FetchedResults<M3UModel>
    @EnvironmentObject
    private var appModel: APPModel
    @State
    private var addM3U = false
    @State
    private var nameFilter: String = ""
    var body: some View {
        let models = m3uModels.filter { model in
            var isIncluded = true
            if nameFilter.count > 0 {
                isIncluded = model.name!.contains(nameFilter)
            }
            return isIncluded
        }
        List(models, id: \.self, selection: $appModel.activeM3UModel) { model in
            #if os(tvOS)
            NavigationLink(value: model) {
                M3UView(model: model)
            }
            #else
            M3UView(model: model)
            #endif
        }
        .searchable(text: $nameFilter)
        .toolbar {
            Button {
                addM3U = true
            } label: {
                Label("Add M3U", systemImage: "plus.app.fill")
            }
        }
        .sheet(isPresented: $addM3U) {
            AddM3UView()
        }
    }

    private func cellView(model: M3UModel) -> some View {
        #if os(tvOS)
        NavigationLink(value: model) {
            M3UView(model: model)
        }
        #else
        M3UView(model: model)
        #endif
    }
}

struct M3UView: View {
    @ObservedObject
    var model: M3UModel
    var body: some View {
        VStack(alignment: .leading) {
            Text(model.name!)
                .font(.title2)
                .foregroundColor(.primary)
            Text("total \(model.count) channels")
                .font(.callout)
                .foregroundColor(.secondary)
            Text(model.m3uURL!.description)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .contextMenu {
            Button {
                model.managedObjectContext?.delete(model)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            Button {
                Task {
                    await _ = model.parsePlaylist(refresh: true)
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise.circle")
            }
            #if !os(tvOS)
            Button {
                #if os(macOS)
                UIPasteboard.general.clearContents()
                UIPasteboard.general.setString(model.m3uURL!.description, forType: .string)
                #else
                UIPasteboard.general.setValue(model.m3uURL!, forPasteboardType: "public.url")
                #endif
            } label: {
                Label("Copy url", systemImage: "doc.on.doc.fill")
            }
            #endif
        }
    }
}

struct AddM3UView: View {
    @State private var url = ""
    @State private var name = ""
    @EnvironmentObject private var appModel: APPModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                TextField("URL", text: $url)
                TextField("Name", text: $name)
            }
            Section {
                Text("Links to playlists you add will be public. All people can see it. But only you can modify and delete")
                Button("Done") {
                    if let url = URL(string: url.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)) {
                        let name = name.trimmingCharacters(in: NSMutableCharacterSet.whitespacesAndNewlines)
                        appModel.addM3U(url: url, name: name.count == 0 ? nil : name)
                    }
                    dismiss()
                }
                #if os(macOS)
                Button("Cancel") {
                    dismiss()
                }
                #endif
            }
        }.padding()
    }
}
