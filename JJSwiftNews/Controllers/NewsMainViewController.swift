//
//  NewsMainViewController.swift
//  JJSwiftDemo
//
//  Created by Mr.JJ on 2017/5/24.
//  Copyright © 2017年 yejiajun. All rights reserved.
//

import UIKit
import SwiftyJSON
import Alamofire
import MBProgressHUD

let kReadedNewsKey = "ReadedNewsDictKey"

class NewsMainViewController: UIViewController {

    // MARK: - Properties
    fileprivate var topicScrollView: JJTopicScrollView?
    fileprivate var bodyScrollView: JJContentScrollView?
    
    var newsTopicArray = [["topic": "头条", "type": "top"],
                          ["topic": "社会", "type": "shehui"],
                          ["topic": "国内", "type": "guonei"],
                          ["topic": "国际", "type": "guoji"],
                          ["topic": "娱乐", "type": "yule"],
                          ["topic": "体育", "type": "tiyu"],
                          ["topic": "军事", "type": "junshi"],
                          ["topic": "科技", "type": "keji"],
                          ["topic": "财经", "type": "caijing"],
                          ["topic": "时尚", "type": "shishang"]]
    
    var topContentArray = ContentArray()
    var norContentArray = ContentArray()
    var lastNewsUniqueKey = ""               // 最后一条资讯的uniquekey
    var currTopicType = ""                   // 最近选择的TopicType
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "资讯"

        let topicNameArray = newsTopicArray.map { $0["topic"]! }
        let topicViewWidth = CGFloat(100)
//        let topicViewWidth = ScreenWidth / CGFloat(newsTopicNameArray.count)
        topicScrollView = JJTopicScrollView(frame: CGRect(x: 0, y: NavBarHeight, width: ScreenWidth, height: 50), topicViewWidth: topicViewWidth)
        if let topicScrollView = self.topicScrollView {
            topicScrollView.setupScrollViewContents(dataSourceArray: topicNameArray)
            topicScrollView.delegate = self
            self.view.addSubview(topicScrollView)
            
            bodyScrollView = JJContentScrollView(frame: CGRect(x: 0, y: topicScrollView.bottom, width: ScreenWidth, height: ScreenHeight - NavBarHeight))
            if let contentScrollView = bodyScrollView {
                contentScrollView.setupScrollView(tableViewCount: topicNameArray.count)
                contentScrollView.delegate = self
                self.view.addSubview(contentScrollView)
                // 在页面初始化后加载数据
                DispatchQueue.main.async {
                    contentScrollView.startPullToRefresh()
                }
            }
        }
    }
    
    deinit {
        topicScrollView = nil
        bodyScrollView = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Functions
    
    // MARK: 请求数据
    fileprivate func requestData(type: String, completionHandler: ((JSON?, JJError?) -> Void)?) {
        guard NetworkReachabilityManager(host: "www.baidu.com")?.isReachable == true else {
            if let completionHandler = completionHandler {
                showPopView(message: "网络异常", showTime: 1)
                completionHandler(nil, JJError.networkError)
            }
            return
        }
        let requestURL = "http://toutiao-ali.juheapi.com/toutiao/index"
        let headers = ["Authorization": "APPCODE fd4e0a674e274e46ad3e26ab508ff21c", "type": type]
        let method = HTTPMethod.get
        let parameters = ["type": type]
        
        Alamofire.request(requestURL, method: method, parameters: parameters, headers: headers).response(completionHandler: { (response) in
            let contentJSON = JSON(data: response.data!)["result"]
            if let completionHandler = completionHandler {
                // 检查数据一致性，用topic_id作为判断依据，防止多次快速请求
                if let requestHeaders = response.request?.allHTTPHeaderFields {
                    if let type = requestHeaders["type"] {
                        if self.currTopicType != type {
                            completionHandler(nil, JJError.dataInconsistentError)
                            return
                        }
                    }
                }
                contentJSON["stat"].intValue == 1 ? completionHandler(contentJSON["data"], nil) : completionHandler(nil, JJError.requetFailedError(contentJSON["msg"].stringValue))
            }
        })
    }

    func showPopView(message: String, showTime: TimeInterval) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.mode = .text
        hud.label.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + showTime) {
            MBProgressHUD.hide(for: self.view, animated: true)
        }
    }
}

// MARK: - JJtopicScrollViewDelegate
extension NewsMainViewController: JJTopicScrollViewDelegate {
    
    internal func didtopicViewChanged(index: Int, value: String) {
        if let contentScrollView = self.bodyScrollView {
            contentScrollView.switchToSelectedContentView(index: index)
        }
    }
}

// MARK: - JJContentScrollViewDelegate
extension NewsMainViewController: JJContentScrollViewDelegate {
    
    internal func didContentViewChanged(index: Int) {
        if let topicScrollView = self.topicScrollView {
            topicScrollView.switchToSelectedtopicView(index: index)
        }
    }
    
    internal func didTableViewStartRefreshing(index: Int) {
        currTopicType = self.newsTopicArray[index]["type"]!
        self.requestData(type: currTopicType) { [unowned self] (contentJSON, error) in
            if let contentScrollView = self.bodyScrollView {
                if let contentJSON = contentJSON {
                    self.topContentArray.removeAll()
                    self.norContentArray.removeAll()
                    self.lastNewsUniqueKey = ""
                    _ = contentJSON.split(whereSeparator: {(index, subJSON) -> Bool in
                        Int(index)! < 4 ? self.topContentArray.append(subJSON) : self.norContentArray.append(subJSON)
                        if index == String(contentJSON.count - 1) {
                            self.lastNewsUniqueKey = subJSON["uniquekey"].stringValue
                        }
                        return true
                    })
                    contentScrollView.refreshTableView(topContentArray: self.topContentArray, norContentArray: self.norContentArray, isPullToRefresh: true)
                } else {
                    if let error = error {
                        print(error.description)
                        contentScrollView.showErrorRetryView(errorMessage: error.description)
                    }
                }
                contentScrollView.stopPullToRefresh()
            }
        }
    }
    
    internal func didTableViewStartLoadingMore(index: Int) {
        currTopicType = self.newsTopicArray[index]["type"]!
        self.requestData(type: currTopicType) { (contentJSON, error) in
            if let contentScrollView = self.bodyScrollView {
                if let contentJSON = contentJSON {
                    contentScrollView.stopLoadingMore()
                    _ = contentJSON.split(whereSeparator: {(index, subJSON) -> Bool in
                        self.norContentArray.append(subJSON)
                        if index == String(contentJSON.count - 1) {
                            self.lastNewsUniqueKey = subJSON["uniquekey"].stringValue
                        }
                        return true
                    })
                    contentScrollView.refreshTableView(topContentArray: self.topContentArray, norContentArray: self.norContentArray, isPullToRefresh: false)
                } else {
                    if let error = error {
                        print(error.description)
                        switch error {
                        case .noMoreDataError:
                            contentScrollView.stopLoadingMoreWithNoMoreData()
                        default:
                            contentScrollView.stopLoadingMore()
                        }
                    }
                }
            }
        }
    }
    
    internal func didTableViewCellSelected(index: Int, isBanner: Bool) {
        let contentJSON = isBanner ? topContentArray[index] : norContentArray[index]
        let uniqueKey = contentJSON["uniquekey"].stringValue
        let requestURLPath = contentJSON["url"].stringValue
        
        let newsDetailController = JJWebViewController()
        newsDetailController.requestURLPath = requestURLPath
        self.navigationController?.pushViewController(newsDetailController, animated: true)
        // 更新已读状态
        var readedNewsDict = UserDefaults.standard.dictionary(forKey: kReadedNewsKey) ?? [String : Bool]()
        readedNewsDict["\(uniqueKey)"] = true
        UserDefaults.standard.set(readedNewsDict, forKey: kReadedNewsKey)
        UserDefaults.standard.synchronize()
        if !isBanner, let contentScrollView = self.bodyScrollView {
            contentScrollView.refreshTabaleCellReadedState(index: index, isBanner: false)
        }
    }
}

private enum JJError: Error {
    case networkError
    case dataInconsistentError
    case jsonParsedError
    case noMoreDataError(String)
    case requetFailedError(String)

    internal var description: String {
        get {
            switch self {
            case .networkError:
                return "网络似乎不给力"
            case .dataInconsistentError:
                return "数据不一致"
            case .jsonParsedError:
                return "JSON解析错误"
            case .noMoreDataError(let msg):
//                return "请求成功，返回错误:\(msg)"
                return "数据异常"
            case .requetFailedError(let msg):
//                return "请求失败:\(msg)"
                return "访问异常"
            }
        }
    }
}

