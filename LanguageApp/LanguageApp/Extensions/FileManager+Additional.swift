//
//  FileManager+Additional.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 15/7/25.
//

import Foundation

extension FileManager {
    func getFolderPath(bundleName: String, folderPath: String) -> Bundle? {
        do {
            let documents = try url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let bundlePath = documents.appendingPathComponent(bundleName, isDirectory: true)
            
            let folder = bundlePath.appendingPathComponent("\(folderPath)")
            
            if !fileExists(atPath: folder.path) {
                try createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: .none)
            }
            return Bundle(url: folder)
        } catch {
            return nil
        }
    }
}
