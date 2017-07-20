//
//  BrowseDirectoryViewController.swift
//  CIFSWrapperSample
//
//  Created by Atsushi Tanaka on 2015/11/22.
//

import UIKit

class BrowseDirectoryViewController: UITableViewController {
    var currentDir: CIFSWrapper.FileInfo? = nil
    var fileList: [CIFSWrapper.FileInfo]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = currentDir?.name ?? ""
        
        let rctrl = UIRefreshControl()
        rctrl.attributedTitle = NSAttributedString(string: "ディレクトリ取得中")
        rctrl.addTarget(self, action: Selector("reloadDirectory"), forControlEvents: .ValueChanged)
        self.refreshControl = rctrl
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if fileList == nil {
            reloadDirectory()
        }
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileList?.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let fileInfo = fileList![indexPath.row]
        if fileInfo.isDirectory {
            let cell = tableView.dequeueReusableCellWithIdentifier("dirCell", forIndexPath: indexPath)
            cell.textLabel?.text = fileInfo.name
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("fileCell", forIndexPath: indexPath)
            cell.textLabel?.text = fileInfo.name
            return cell
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        guard let fileList = self.fileList else { return }
        let selectFile = fileList[indexPath.row]
        if selectFile.isDirectory {
            let vc = self.storyboard?.instantiateViewControllerWithIdentifier("BrowseDirectoryViewController") as! BrowseDirectoryViewController
            vc.currentDir = selectFile
            self.navigationController!.showViewController(vc, sender: self)
        }
    }
    
    @IBAction func addFileTouchDown(sender: UIBarButtonItem) {
    }
    
    func reloadDirectory() {
        if !refreshControl!.refreshing {
            refreshControl?.beginRefreshing()
        }
        if currentDir == nil {
            self.refreshControl?.endRefreshing()
            return
        }

        CIFSWrapper.getFileInfoList(currentDir!.url, type: .FileOrDirectory) { [weak self] (files, error) in
            if self == nil { return }
            if let files = files {
                let sortedFiles = files.sort() { (x, y) in
                    if x.isDirectory == y.isDirectory {
                        return x.name < y.name
                    } else {
                        return x.isDirectory
                    }
                }
                self!.fileList = sortedFiles
                self!.tableView.reloadData()
                self!.refreshControl!.endRefreshing()
            } else {
                self!.refreshControl!.endRefreshing()
                self!.presentOKAlert("エラー", message: "ディレクトリ取得に失敗しました", preferredStyle: .Alert)
            }
        }
    }
    
    func addFile() {
        
    }
}
