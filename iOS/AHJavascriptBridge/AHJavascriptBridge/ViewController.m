//
//  ViewController.m
//  AHKit
//
//  Created by Alan Miu on 15/12/17.
//  Copyright (c) 2015年 AutoHome. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    NSArray *_titles;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.extendedLayoutIncludesOpaqueBars = YES;
    
    _titles = @[@"JavascriptBridge 1.0", @"....."];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    static NSString *CellIdentifier = @"CELL";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.textLabel.text = _titles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        UIViewController *viewController = [[self storyboard] instantiateViewControllerWithIdentifier:@"AHJavascriptBridgeTest"];
        [[self navigationController] pushViewController:viewController animated:YES];
    }
}

@end
