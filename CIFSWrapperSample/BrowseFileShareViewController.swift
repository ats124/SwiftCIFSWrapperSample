//
//  BrowseFileShareViewController.swift
//  CIFSWrapperSample
//
//  Created by Atsushi Tanaka on 2015/11/15.
//

import UIKit

class BrowseFileShareViewController: UITableViewController {
    
    /// ホスト名
    var hostName: String = ""
    // ファイル名
    var userName: String = "guest"
    // パスワード
    var password: String = ""
    // ファイル共有一覧
    private var fileShares: [CIFSWrapper.FileInfo]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        self.navigationItem.title = hostName
        
        let rctrl = UIRefreshControl()
        rctrl.attributedTitle = NSAttributedString(string: "ファイル共有リスト取得中")
        rctrl.addTarget(self, action: Selector("reloadFileShares"), forControlEvents: .ValueChanged)
        self.refreshControl = rctrl
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if fileShares == nil {
            showAuthAlert()
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int  {
        return fileShares?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("defaultCell", forIndexPath: indexPath)
        cell.textLabel?.text = fileShares![indexPath.row].name
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        performSegueWithIdentifier("toBrowseDirectory", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "toBrowseDirectory" {
            guard let selectedRow = tableView?.indexPathForSelectedRow?.row,
                directoryView = segue.destinationViewController as? BrowseDirectoryViewController else { return }
            directoryView.currentDir = fileShares![selectedRow]
        }
    }
    
    func showAuthAlert() {
        let authAlert = UIAlertController(title: "ユーザー名とパスワード", message: "\(hostName)に接続するためのユーザー名とパスワードを入力してください", preferredStyle: .Alert)
        weak var userText: UITextField?
        authAlert.addTextFieldWithConfigurationHandler { [unowned self] in
            $0.text = self.userName
            $0.placeholder = "ユーザー名"
            userText = $0
        }
        weak var passText: UITextField?
        authAlert.addTextFieldWithConfigurationHandler { [unowned self] in
            $0.secureTextEntry = true
            $0.text = self.password
            $0.placeholder = "パスワード"
            passText = $0
        }
        authAlert.addAction(UIAlertAction(title: "OK", style: .Default) { [unowned self] _ in
            self.userName = userText!.text ?? ""
            self.password = passText!.text ?? ""
            self.reloadFileShares()
        })
        authAlert.addAction(UIAlertAction(title: "Cancel", style: .Cancel){ [unowned self] _ in
            self.performSegueWithIdentifier("unwindToBrowseServer", sender: self)
        })
        self.presentViewController(authAlert, animated: true, completion: nil)
    }
    
    func reloadFileShares() {
        if !refreshControl!.refreshing {
            refreshControl?.beginRefreshing()
        }
        let userName = self.userName.stringByAddingPercentEncodingWithAllowedCharacters(.URLPathAllowedCharacterSet()) ?? ""
        let password = self.password.stringByAddingPercentEncodingWithAllowedCharacters(.URLPathAllowedCharacterSet()) ?? ""
        let hostName = self.hostName.stringByAddingPercentEncodingWithAllowedCharacters(.URLPathAllowedCharacterSet()) ?? ""
        guard let pathUrl = NSURL(string: "smb://\(userName):\(password)@\(hostName)/") else {
            self.refreshControl!.endRefreshing()
            self.presentOKAlert("エラー", message: "ユーザ名またはパスワード、ホスト名が不正です", preferredStyle: .Alert)
            return
        }
        CIFSWrapper.getFileInfoList(pathUrl, type: .FileOrDirectory) { [weak self] (fileShares, error) in
            guard let sself = self else { return }
            
            if let fileShares = fileShares {
                sself.fileShares = fileShares
                sself.tableView.reloadData()
                sself.refreshControl!.endRefreshing()
            } else {
                sself.refreshControl!.endRefreshing()
                switch (error ?? .Unknown(errno: 0) ) {
                case .OpeNotPermited:
                    sself.presentOKAlert("エラー", message: "ユーザ名またはパスワードが違います", preferredStyle: .Alert)
                default:
                    sself.presentOKAlert("エラー", message: "サーバーにアクセスできませんでした", preferredStyle: .Alert)
                }
            }
        }
    }
}
