//
// Copyright 2011 Jeff Verkoeyen
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// See: http://bit.ly/hS5nNh for unit test macros.

#import <SenTestingKit/SenTestingKit.h>

#import "NimbusCore.h"
#import "NimbusModels.h"

@interface NITableViewModelTests : SenTestCase {
}

@end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NITableViewModelTests


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testEmptyTableViewModel {
  NITableViewModel* model = [[[NITableViewModel alloc] init] autorelease];

  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 0, @"The model should be empty.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should always be at least 1 section.");
  
  model = [[[NITableViewModel alloc] initWithListArray:nil delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 0, @"The model should be empty.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should always be at least 1 section.");
  
  model = [[[NITableViewModel alloc] initWithSectionedArray:nil delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 0, @"The model should be empty.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should always be at least 1 section.");
  
  model = [[[NITableViewModel alloc] initWithListArray:[NSArray array] delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 0, @"The model should be empty.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should always be at least 1 section.");
  
  model = [[[NITableViewModel alloc] initWithSectionedArray:[NSArray array] delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 0, @"The model should be empty.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should always be at least 1 section.");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testListTableViewModel {
  NSArray* contents = [NSArray arrayWithObjects:
                       @"This is a string",
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 2" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       nil];
  NITableViewModel* model = [[[NITableViewModel alloc] initWithListArray:contents delegate:nil] autorelease];

  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 4, @"The model should have 4 rows.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 1, @"There should be 1 section.");
  STAssertNil([model tableView:nil titleForHeaderInSection:0], @"There should be no section title.");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testListTableViewModel_objectAtIndexPath {
  id object1 = [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"];
  id object2 = [NSArray array];
  id object3 = [NSSet set];
  NSArray* contents = [NSArray arrayWithObjects:
                       @"This is a string",
                       object1,
                       object2,
                       object3,
                       nil];
  NITableViewModel* model = [[[NITableViewModel alloc] initWithListArray:contents delegate:nil] autorelease];
  
  STAssertEquals([model objectAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]], @"This is a string", @"The first object should be the string.");
  STAssertEquals([model objectAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]], object1, @"Object mismatch.");
  STAssertEquals([model objectAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]], object2, @"Object mismatch.");
  STAssertEquals([model objectAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:0]], object3, @"Object mismatch.");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testSectionedTableViewModel {
  NSArray* contents = [NSArray arrayWithObjects:
                       @"Section 1",
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 2" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       @"Section 2",
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       @"Section 3",
                       @"Section 4",
                       @"Section 5",
                       nil];
  NITableViewModel* model = [[[NITableViewModel alloc] initWithSectionedArray:contents delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 3, @"The first section should have 3 rows.");
  STAssertEquals([model tableView:nil numberOfRowsInSection:1], 2, @"The second section should have 2 rows.");
  STAssertEquals([model tableView:nil numberOfRowsInSection:2], 0, @"The third section should have 0 rows.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 5, @"There should be 5 sections.");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)testSectionedTableViewModelWithFooters {
  NSArray* contents = [NSArray arrayWithObjects:
                       @"Section 1",
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 2" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       [NITableViewModelFooter footerWithTitle:@"Footer 1"],
                       @"Section 2",
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       [NITableViewModelFooter footerWithTitle:@"Footer 2"],
                       @"Section 3",
                       [NITableViewModelFooter footerWithTitle:@"Footer 3"],
                       [NITableViewModelFooter footerWithTitle:@"Footer 4"],
                       [NSDictionary dictionaryWithObject:@"Row 1" forKey:@"title"],
                       [NSDictionary dictionaryWithObject:@"Row 3" forKey:@"title"],
                       [NITableViewModelFooter footerWithTitle:@"Footer 5"],
                       @"Section 6",
                       @"Section 7",
                       nil];
  NITableViewModel* model = [[[NITableViewModel alloc] initWithSectionedArray:contents delegate:nil] autorelease];
  
  STAssertEquals([model tableView:nil numberOfRowsInSection:0], 3, @"The first section should have 3 rows.");
  STAssertEquals([model tableView:nil numberOfRowsInSection:1], 2, @"The second section should have 2 rows.");
  STAssertEquals([model tableView:nil numberOfRowsInSection:2], 0, @"The third section should have 0 rows.");
  STAssertEquals([model tableView:nil numberOfRowsInSection:3], 0, @"The fourth section should have 0 rows.");
  STAssertEquals([model numberOfSectionsInTableView:nil], 7, @"There should be 7 sections.");
  STAssertEquals([model tableView:nil titleForHeaderInSection:0], @"Section 1", @"The titles should match.");
  STAssertEquals([model tableView:nil titleForHeaderInSection:1], @"Section 2", @"The titles should match.");
  STAssertEquals([model tableView:nil titleForFooterInSection:0], @"Footer 1", @"The titles should match.");
  STAssertEquals([model tableView:nil titleForFooterInSection:1], @"Footer 2", @"The titles should match.");
  STAssertNil([model tableView:nil titleForFooterInSection:6], @"There should not be a title.");
}


@end
