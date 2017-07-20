//
//  CIFSWrapper.swift
//  CIFSWrapper
//
//  Created by Atsushi Tanaka on 2015/10/25.
//

import Foundation


/// CIFSラッパークラス
public final class CIFSWrapper {

    /// CIFS/SMBサーバーのファイル情報
    public struct FileInfo {
        /// CIFS/SMBサーバーパス(URL)
        let url: NSURL
        /// ファイル名
        let name: String
        /// ディレクトリかどうか
        let isDirectory: Bool
        
        /// - parameter path: CIFS/SMB URL
        /// - parameter isDirectory: ディレクトリの場合はtrue、ファイルの場合はfalse
        private init(url u: NSURL, isDirectory dir: Bool) {
            url = u
            isDirectory = dir
            name = url.lastPathComponent ?? ""
        }
    }
    
    /// CIFSエラー
    public enum CIFSError : ErrorType {
        case InvalidArgument
        case OutOfMemorry
        case PermissionDenied
        case NoSuchFileOrDirectory
        case NotDirectory
        case IsDirectory
        case OpeNotPermited
        case ShareNotExist
        case AlreadyExists
        case DirectoryNotEmpty
        case ConnectionRefused
        case Unknown(errno: Int32)
        
        /// errnoからエラーを変換
        public static func fromErrno() -> CIFSError {
            return fromErrno(errno: errno)
        }
        
        /// errnoからエラーを変換
        public static func fromErrno(errno e: Int32) -> CIFSError {
            let errnoMap: Dictionary<Int32, CIFSError> = [
                EINVAL:         .InvalidArgument,
                ENOMEM:         .OutOfMemorry,
                EACCES:         .PermissionDenied,
                ENOENT:         .NoSuchFileOrDirectory,
                ENOTDIR:        .NotDirectory,
                EISDIR:         .IsDirectory,
                EPERM:          .OpeNotPermited,
                ENODEV:         .ShareNotExist,
                EEXIST:         .AlreadyExists,
                ENOTEMPTY:      .DirectoryNotEmpty,
                ECONNREFUSED:   .ConnectionRefused
            ]
            if let err = errnoMap[e] {
                return err
            } else {
                return .Unknown(errno: e)
            }
        }
    }
    
    /// CopyToServerErrorメソッドのエラー
    public enum CopyError : ErrorType {
        case LocalFileNotFound
        case LocalFileError(error: ErrorType)
        case CIFS(error: CIFSError)
    }
    
    /// 検索対象タイプ
    public enum TargetType {
        case File
        case Directory
        case FileOrDirectory
    }
    
    /// 同じネットワーク内のCIFS/SMBサーバーのホスト一覧を取得する
    /// - returns ホスト一覧
    public static func getHosts() throws -> [String] {
        let dirents = try getDirEntries("smb:///")
        var hosts: [String] = []
        for dirent in dirents {
            if dirent.type == .Server {
                hosts.append(dirent.name)
            }
        }
        return hosts
    }
    
    /// 同じネットワーク内のCIFS/SMBサーバーのホスト一覧を取得する(非同期)
    /// - parameter callback: 結果を処理するコールバック
    public static func getHosts(callback: ([String]?, error: CIFSError?)->Void) {
        let callbackQ = NSOperationQueue.currentQueue()?.underlyingQueue
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var hosts: [String]?
            var err: CIFSError?
            do {
                hosts = try getHosts()
                err = nil
            } catch let e as CIFSError {
                hosts = nil
                err = e
            } catch {
                hosts = nil
                err = .Unknown(errno: 0)
            }
            dispatch_async(callbackQ ?? dispatch_get_main_queue()) { callback(hosts, error: err) }
        }
    }
    
    /// 指定したSMBサーバーのファイル一覧を取得する
    /// - parameter url: CIFS/SMB URL
    /// - parameter type: 検索対象
    /// - returns ファイル一覧
    public static func getFileInfoList(url: NSURL, type: TargetType) throws -> [FileInfo] {
        guard let exUrl = extractUrl(url) else { throw CIFSError.InvalidArgument }
        let dirents = try getDirEntries(exUrl.noAuthUrl, auth: exUrl.auth)
        var files: [FileInfo] = []
        for dirent in dirents {
            guard let smbType = dirent.type, escapeName = dirent.name.stringByAddingPercentEncodingWithAllowedCharacters(.URLPathAllowedCharacterSet()) else { continue }
            switch (smbType) {
            case .FileShare, .Directory:
                if dirent.name == "." || dirent.name == ".." {
                    continue
                }
                if type == .Directory || type == .FileOrDirectory {
                    files.append(FileInfo(url: NSURL(string: escapeName + "/", relativeToURL: url)!.absoluteURL, isDirectory: true))
                } else {
                    continue
                }
            case .File:
                if type == .File || type == .FileOrDirectory {
                    files.append(FileInfo(url: NSURL(string: escapeName, relativeToURL: url)!.absoluteURL, isDirectory: false))
                } else {
                    continue
                }
            default:
                continue
            }
        }
        return files
    }
    
    /// 指定したSMBサーバーのファイル一覧を取得する(非同期)
    /// - parameter url: CIFS/SMB URL
    /// - parameter type: 検索対象
    /// - returns ファイル一覧
    public static func getFileInfoList(url: NSURL, type: TargetType, callback: ([FileInfo]?, error: CIFSError?)->Void) {
        let callbackQ = NSOperationQueue.currentQueue()?.underlyingQueue
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var files: [FileInfo]?
            var err: CIFSError?
            do {
                files = try getFileInfoList(url, type: type)
                err = nil
            } catch let e as CIFSError {
                files = nil
                err = e
            } catch {
                files = nil
                err = .Unknown(errno: 0)
            }
            dispatch_async(callbackQ ?? dispatch_get_main_queue()) { callback(files, error: err) }
        }
    }
    
    /// 指定ファイルをローカルからSMBサーバーにコピーする
    /// - parameter dstUrl: コピー元 URL
    /// - parameter dstUrl: コピー先 CIFS/SMB URL
    public static func copyToServer(srcUrl: NSURL, dstUrl: NSURL) throws {
        guard let exUrl = extractUrl(dstUrl) else { throw CopyError.CIFS(error: CIFSError.InvalidArgument) }

        let srcData: NSData
        do {
            srcData = try NSData(contentsOfURL: srcUrl, options: NSDataReadingOptions.DataReadingMappedIfSafe)
        } catch let e  {
            throw CopyError.LocalFileError(error: e)
        }
        
        do {
            try writeFile(exUrl.noAuthUrl, auth: exUrl.auth, writeData: srcData, overwrite: true)
        } catch let e as CIFSError {
            throw CopyError.CIFS(error: e)
        }
    }
    
    /// 指定ファイルをローカルからSMBサーバーにコピーする(非同期)
    /// - parameter dstUrl: コピー元 URL
    /// - parameter dstUrl: コピー先 CIFS/SMB URL
    public static func copyToServer(srcUrl: NSURL, dstUrl: NSURL, callback: (error: CopyError?)->Void) {
        let callbackQ = NSOperationQueue.currentQueue()?.underlyingQueue
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var err: CopyError?
            do {
                try copyToServer(srcUrl, dstUrl: dstUrl)
                err = nil
            } catch let e as CopyError {
                err = e
            } catch {
                err = .CIFS(error: .Unknown(errno: 0))
            }
            dispatch_async(callbackQ ?? dispatch_get_main_queue()) { callback(error: err) }
        }
    }
    
    /// 指定ファイルをSMBサーバーからローカルにコピーする
    /// - parameter dstUrl: コピー元 CIFS/SMB URL
    /// - parameter dstUrl: コピー先 URL
    public static func copyFromServer(srcUrl: NSURL, dstUrl: NSURL) throws {
        guard let exUrl = extractUrl(srcUrl) else { throw CopyError.CIFS(error: CIFSError.InvalidArgument) }
        let readData: NSData
        do {
            readData = try readFile(exUrl.noAuthUrl, auth: exUrl.auth)
        } catch let e as CIFSError {
            throw CopyError.CIFS(error: e)
        }
        readData.writeToURL(dstUrl, atomically: false)
    }
    
    /// 指定ファイルをSMBサーバーからローカルにコピーする(非同期)
    /// - parameter dstUrl: コピー元 CIFS/SMB URL
    /// - parameter dstUrl: コピー先 URL
    public static func copyFromServer(srcUrl: NSURL, dstUrl: NSURL, callback: (error: CopyError?)->Void) {
        let callbackQ = NSOperationQueue.currentQueue()?.underlyingQueue
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var err: CopyError?
            do {
                try copyFromServer(srcUrl, dstUrl: dstUrl)
                err = nil
            } catch let e as CopyError {
                err = e
            } catch {
                err = .CIFS(error: .Unknown(errno: 0))
            }
            dispatch_async(callbackQ ?? dispatch_get_main_queue()) { callback(error: err) }
        }
    }
    
    /// SMBエントリ種別
    private enum SMBType : UInt32 {
        case Workgroup = 1
        case Server = 2
        case FileShare = 3
        case PrinterShare = 4
        case CommsShare = 5
        case IpcShare = 6
        case Directory = 7
        case File = 8
        case Link = 9
    }
    
    // SMBディレクトリエントリ
    private class SMBDirEnt {
        let type: SMBType?
        let name: String

        init(smbc_type: UInt32, name nm: UnsafeMutablePointer<CChar>) {
            type = SMBType(rawValue: smbc_type)
            name = String.fromCString(nm) ?? ""
        }
        
        init(smbc_type: UInt32, name nm: String) {
            type = SMBType(rawValue: smbc_type)
            name = nm
        }
    }

    /// SMB認証情報
    private class SMBAuth {
        let workgroup: String
        let userName: String
        let password: String
        static let Guest = SMBAuth(userName: "guest", password: "")
        
        init(workgroup w: String = "", userName u: String, password p: String) {
            workgroup = w
            userName = u
            password = p
        }
    }

    /// 指定したURLからユーザー名とパスワード、ユーザ名とパスワードを除外したURLを取得
    private static func extractUrl(url: NSURL) -> (noAuthUrl: String, auth: SMBAuth)? {
        guard let noAuthUrl = NSURL(scheme: url.scheme, host: url.host, path: url.path!) else { return nil }
        return (noAuthUrl: noAuthUrl.absoluteString, auth: SMBAuth(userName: url.user ?? "", password: url.password ?? ""))
    }
    
    /// SMBコンテキスト生成
    private static func createContext(auth: SMBAuth = SMBAuth.Guest) throws -> UnsafeMutablePointer<SMBCCTX> {
        let ctx = smbc_new_context()
        if ctx == nil {
            throw CIFSError.fromErrno()
        }
        
        // 認証コールバックセット
        smbc_setFunctionAuthDataWithContext(ctx, authData)
        
        // コールバック先で認証情報を受け取れるようにコンテキストのユーザデータに認証情報をセット
        // Cポインタで保持する必要があるので参照カウントを明示的にインクリメント
        let unmanagedAuth = Unmanaged.passRetained(auth)
        let pAuth = UnsafeMutablePointer<Void>(unmanagedAuth.toOpaque())
        smbc_setOptionUserData(ctx, pAuth)

        if smbc_init_context(ctx) == nil {
            let err = CIFSError.fromErrno()
            smbc_free_context(ctx, 1);
            unmanagedAuth.release()
            throw err
        }
        
        return ctx
    }
    
    /// SMBコンテキスト破棄
    private static func deleteContext(ctx: UnsafeMutablePointer<SMBCCTX>) {
        let pAuth = smbc_getOptionUserData(ctx)
        if pAuth != nil {
            Unmanaged<SMBAuth>.fromOpaque(COpaquePointer(pAuth)).release()
        }
        cifswrapper_PurgeCachedServers(ctx)
        smbc_free_context(ctx, 1)
    }
    
    /// SMBディレクトリエントリ取得
    private static func getDirEntries(path: String, auth: SMBAuth = SMBAuth.Guest) throws -> [SMBDirEnt] {
        let ctx = try createContext(auth)
        defer {
            deleteContext(ctx)
        }
        
        let fd = smbc_getFunctionOpendir(ctx)(ctx, path.cStringUsingEncoding(NSUTF8StringEncoding)!)
        if fd == nil {
            throw CIFSError.fromErrno()
        }
        defer {
            smbc_getFunctionClose(ctx)(ctx, fd)
        }
        
        var dirents: [SMBDirEnt] = []
        while true {
            let dirent = smbc_getFunctionReaddir(ctx)(ctx, fd);
            if dirent != nil {
                withUnsafePointer(&dirent.memory.name) {
                    dirents.append(SMBDirEnt(smbc_type: dirent.memory.smbc_type, name: String.fromCString($0) ?? ""))
                }
            } else {
                break;
            }
        }
        
        return dirents
    }
    
    /// SMBファイル書込
    private static func writeFile(path: String, auth: SMBAuth = SMBAuth.Guest, writeData: NSData, overwrite: Bool) throws -> Int {
        // SMBコンテキスト生成
        let ctx = try createContext(auth)
        defer {
            deleteContext(ctx)
        }
    
        // SMBファイル作成
        var file: COpaquePointer = nil
        path.withCString() {
            file = smbc_getFunctionCreat(ctx)(ctx, $0, (mode_t)(O_WRONLY|O_CREAT|(overwrite ? O_TRUNC : O_EXCL)))
        }
        if file == nil {
            throw CIFSError.fromErrno()
        }
        defer {
            smbc_getFunctionClose(ctx)(ctx, file)
        }
        
        // SMBファイル書込
        let writeFunc = smbc_getFunctionWrite(ctx)
        var writeBytes = UnsafePointer<UInt8>(writeData.bytes)
        var remindLenBytes = writeData.length
        while remindLenBytes > 0 {
            let writelen = writeFunc(ctx, file, writeBytes, remindLenBytes)
            if writelen == 0 {
                break
            } else if writelen < 0 {
                throw CIFSError.fromErrno()
            }
            remindLenBytes -= writelen
            writeBytes += writelen
        }
        
        return writeData.length - remindLenBytes
    }
    
    /// SMBファイル読込
    private static func readFile(path: String, auth: SMBAuth = SMBAuth.Guest) throws -> NSData {
        // SMBコンテキスト生成
        let ctx = try createContext(auth)
        defer {
            deleteContext(ctx)
        }
        
        // SMBファイルオープン
        var file: COpaquePointer = nil
        path.withCString() {
            file = smbc_getFunctionOpen(ctx)(ctx, $0, O_RDONLY, 0)
        }
        if file == nil {
            throw CIFSError.fromErrno()
        }
        defer {
            smbc_getFunctionClose(ctx)(ctx, file)
        }
        
        // SMBファイル読込
        let readFunc = smbc_getFunctionRead(ctx)
        let data = NSMutableData()
        var buffer = [UInt8](count: 1024 * 1024, repeatedValue: 0)
        repeat {
            let readLen = readFunc(ctx, file, &buffer[0], buffer.count)
            if readLen == 0 {
                break
            } else if readLen < 0 {
                throw CIFSError.fromErrno()
            } else {
                data.appendBytes(buffer, length: readLen)
            }
        } while true
        
        return data
    }
}


/// 認証コールバック
func authData(ctx: UnsafeMutablePointer<SMBCCTX>, server: UnsafePointer<Int8>, share: UnsafePointer<Int8>, wrkgrp: UnsafeMutablePointer<Int8>, wrkgrplen: Int32, usr:UnsafeMutablePointer<Int8>, usrlen: Int32, pass: UnsafeMutablePointer<Int8>, passlen: Int32) -> Void {
    let pAuth = smbc_getOptionUserData(ctx)
    var auth: CIFSWrapper.SMBAuth?
    if pAuth != nil {
        // CポインタからSwiftオブジェクトに戻す
        // スコープを抜けても保持し続ける必要があるので参照カウンタを減らさないようにする
        auth = Unmanaged<CIFSWrapper.SMBAuth>.fromOpaque(COpaquePointer(pAuth)).takeUnretainedValue()
    } else {
        auth = nil
    }
    
    if auth?.workgroup ?? "" !=  "" {
        auth!.workgroup.withCString {
            strncpy(wrkgrp, $0, wrkgrplen - 1)
        }
    } else {
        wrkgrp[0] = 0
    }
    
    if auth?.userName ?? "" != "" {
        auth!.userName.withCString {
            strncpy(usr, $0, usrlen - 1)
        }
    } else {
        strncpy(usr, "guest", usrlen - 1)
    }
    
    if auth?.password ?? "" != "" {
        auth!.password.withCString {
            strncpy(pass, $0, passlen - 1)
        }
    } else {
        pass[0] = 0
    }
}
