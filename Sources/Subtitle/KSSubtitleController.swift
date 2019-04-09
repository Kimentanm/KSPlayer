//
//  File.swift
//  KSSubtitle
//
//  Created by kintan on 2018/8/3.
//

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public protocol SubtitleViewProtocol {
    var selectedInfo: KSObservable<SubtitleInfo> { get }
    func setupDatas(infos: [SubtitleInfo])
}

public class KSSubtitleController {
    private var cacheDataSouce = CacheDataSouce()
    private var subtitleDataSouces: [SubtitleDataSouce] = []
    private var infos = [SubtitleInfo]()
    private var subtitleName: String?
    public var subtitle: KSSubtitleProtocol?
    public var selectWithFilePath: ((KSSubtitleProtocol?, Error?) -> Void)?
    public var srtListCount: KSObservable<Int> = KSObservable(0)

    public var view: UIView & SubtitleViewProtocol
    public init(customControlView: (UIView & SubtitleViewProtocol)? = nil) {
        if let customView = customControlView {
            view = customView
        } else {
            view = KSSubtitleView()
        }
        view.isHidden = true
        subtitleDataSouces = [cacheDataSouce]
        view.selectedInfo.observer = { [weak self] _, info in
            guard let self = self, let selectWithFilePath = self.selectWithFilePath else { return }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.view.isHidden = true
            }
            if let info = info as? MakeSubtitle {
                info.makeSubtitle(completion: selectWithFilePath)
            }
        }
    }

    public func searchSubtitle(name: String) {
        let subtitleName = (name as NSString).deletingPathExtension
        infos.removeAll()
        srtListCount.value = infos.count
        for subtitleDataSouce in subtitleDataSouces {
            searchSubtitle(datasouce: subtitleDataSouce, name: subtitleName)
        }
        self.subtitleName = subtitleName
    }

    public func remove(dataSouce: SubtitleDataSouce) {
        subtitleDataSouces.removeAll { $0 === dataSouce }
        runInMainqueue { [weak self] in
            guard let self = self else { return }
            self.infos.removeAll { $0.subtitleDataSouce === dataSouce }
            self.srtListCount.value = self.infos.count
            self.view.setupDatas(infos: self.infos)
        }
    }

    public func add(dataSouce: SubtitleDataSouce) {
        subtitleDataSouces.append(dataSouce)
        if let dataSouce = dataSouce as? SubtitletoCache {
            dataSouce.cache = cacheDataSouce
        }
        if let subtitleName = subtitleName {
            searchSubtitle(datasouce: dataSouce, name: subtitleName)
        }
    }

    public func filterInfos(_ isIncluded: (SubtitleInfo) -> Bool) -> [SubtitleInfo] {
        return infos.filter(isIncluded)
    }

    private func searchSubtitle(datasouce: SubtitleDataSouce, name: String) {
        datasouce.searchSubtitle(name: name) { array in
            if let array = array {
                array.forEach { $0.subtitleDataSouce = datasouce }
                runInMainqueue { [weak self] in
                    guard let self = self else { return }
                    self.infos.append(contentsOf: array)
                    self.srtListCount.value = self.infos.count
                    self.view.setupDatas(infos: self.infos)
                }
            }
        }
    }
}
