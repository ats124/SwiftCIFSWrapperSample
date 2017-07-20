//
//  ViewController.swift
//  CIFSWrapperSample
//
//  Created by Atsushi Tanaka on 2015/11/08.
//

import UIKit

class BrowseServerViewController: UITableViewController {
    
    var fixedHosts: [String] = []
    var hosts: [String]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rctrl = UIRefreshControl()
        rctrl.attributedTitle = NSAttributedString(string: "サーバーリスト取得中")
        rctrl.addTarget(self, action: Selector("reloadServers"), forControlEvents: .ValueChanged)
        self.refreshControl = rctrl
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if hosts == nil {
            reloadServers()
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int  {
        return fixedHosts.count + (hosts?.count ?? 0)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath:NSIndexPath) -> UITableViewCell {
        let host: String
        if indexPath.row < fixedHosts.count {
            host = fixedHosts[indexPath.row]
        } else {
            host = hosts?[indexPath.row - fixedHosts.count] ?? ""
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier("defaultCell", forIndexPath: indexPath)
        cell.textLabel?.text = host
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        performSegueWithIdentifier("toBrowseFileShare", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "toBrowseFileShare" {
            guard let selectedRow = tableView?.indexPathForSelectedRow?.row,
                fileShareView = segue.destinationViewController as? BrowseFileShareViewController else { return }
            let host: String
            if selectedRow < fixedHosts.count {
                host = fixedHosts[selectedRow]
            } else {
                host = hosts?[selectedRow - fixedHosts.count] ?? ""
            }
            fileShareView.hostName = host
        }
    }
    
    @IBAction func addButtonTouchDown(sender: UIBarButtonItem) {
        addServer()
    }
    
    @IBAction func unwindToBrowseServer(segue: UIStoryboardSegue) {
        
    }
    
    func reloadServers() {
        if !refreshControl!.refreshing {
            refreshControl?.beginRefreshing()
        }
        CIFSWrapper.getHosts() { [weak self] (hosts, error) -> Void in
            guard let sself = self else { return }
            if let h = hosts {
                sself.hosts = h
                sself.tableView.reloadData()
            } else {
                sself.hosts = []
                sself.presentOKAlert("エラー", message: "サーバー一覧取得に失敗しました", preferredStyle: .Alert)
            }
            sself.refreshControl!.endRefreshing()
        }
    }
    
    func addServer() {
        let addServerAlert = UIAlertController(title: "サーバー追加", message: "サーバー名を入力してください", preferredStyle: .Alert)
        weak var userText: UITextField?
        addServerAlert.addTextFieldWithConfigurationHandler {
            $0.placeholder = "サーバー名"
            userText = $0
        }
        addServerAlert.addAction(UIAlertAction(title: "OK", style: .Default) { [unowned self] _ in
            if "" != userText!.text ?? "" && !self.fixedHosts.contains(userText!.text!) {
                self.fixedHosts.append(userText!.text!)
                self.tableView.reloadData()
            }
        })
        addServerAlert.addAction(UIAlertAction(title: "Cancel", style: .Cancel){ _ in })
        self.presentViewController(addServerAlert, animated: true, completion: nil)
        
    }
}

