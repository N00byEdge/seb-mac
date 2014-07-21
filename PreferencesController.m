//
//  PreferencesController.m
//  Safe Exam Browser
//
//  Created by Daniel R. Schneider on 18.04.11.
//  Copyright (c) 2010-2014 Daniel R. Schneider, ETH Zurich, 
//  Educational Development and Technology (LET), 
//  based on the original idea of Safe Exam Browser 
//  by Stefan Schneider, University of Giessen
//  Project concept: Thomas Piendl, Daniel R. Schneider, 
//  Dirk Bauer, Kai Reuter, Tobias Halbherr, Karsten Burger, Marco Lehre, 
//  Brigitte Schmucki, Oliver Rahs. French localization: Nicolas Dunand
//
//  ``The contents of this file are subject to the Mozilla Public License
//  Version 1.1 (the "License"); you may not use this file except in
//  compliance with the License. You may obtain a copy of the License at
//  http://www.mozilla.org/MPL/
//  
//  Software distributed under the License is distributed on an "AS IS"
//  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
//  License for the specific language governing rights and limitations
//  under the License.
//  
//  The Original Code is Safe Exam Browser for Mac OS X.
//  
//  The Initial Developer of the Original Code is Daniel R. Schneider.
//  Portions created by Daniel R. Schneider are Copyright 
//  (c) 2010-2014 Daniel R. Schneider, ETH Zurich, Educational Development
//  and Technology (LET), based on the original idea of Safe Exam Browser 
//  by Stefan Schneider, University of Giessen. All Rights Reserved.
//  
//  Contributor(s): ______________________________________.
//

// Controller for the preferences window, populates it with panes

#import "PreferencesController.h"
#import "MBPreferencesController.h"
#import "NSUserDefaults+SEBEncryptedUserDefaults.h"
#import "SEBConfigFileManager.h"
#import "SEBCryptor.h"


@implementation PreferencesController


// Getter methods for write-only properties

//- (NSString *)currentConfigPassword {
//    [NSException raise:NSInternalInconsistencyException
//                format:@"property is write-only"];
//    return nil;
//}

- (SecKeyRef)currentConfigKeyRef {
    [NSException raise:NSInternalInconsistencyException
                format:@"property is write-only"];
    return nil;
}


- (void)awakeFromNib
{
    [self initPreferencesWindow];
}


- (void)showPreferences:(id)sender
{
    [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
	[[MBPreferencesController sharedController] showWindow:sender];
}


- (BOOL)preferencesAreOpen {
    return [[MBPreferencesController sharedController].window isVisible];
}


- (void)windowWillClose:(NSNotification *)notification
{
    [[NSApplication sharedApplication] stopModal];
    // Post a notification that preferences were closed
    if (self.preferencesAreOpen && !self.refreshingPreferences) {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"preferencesClosed" object:self];
    }
}


- (void)initPreferencesWindow
{
    // Save current settings
    // Get key/values from private UserDefaults
//    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
//    NSDictionary *privatePreferences = [preferences dictionaryRepresentationSEB];
    self.refreshingPreferences = NO;
    
    [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
    [[MBPreferencesController sharedController] openWindow];
    // Set the modules for preferences panes
	PrefsGeneralViewController *general = [[PrefsGeneralViewController alloc] initWithNibName:@"PreferencesGeneral" bundle:nil];
    general.preferencesController = self;
    
	self.SEBConfigVC = [[PrefsSEBConfigViewController alloc] initWithNibName:@"PreferencesSEBConfig" bundle:nil];
    self.SEBConfigVC.preferencesController = self;
    
    // Set settings credentials in the SEB config prefs pane
    [self setConfigFileCredentials];
    
	PrefsAppearanceViewController *appearance = [[PrefsAppearanceViewController alloc] initWithNibName:@"PreferencesAppearance" bundle:nil];
	PrefsBrowserViewController *browser = [[PrefsBrowserViewController alloc] initWithNibName:@"PreferencesBrowser" bundle:nil];
	PrefsDownUploadsViewController *downuploads = [[PrefsDownUploadsViewController alloc] initWithNibName:@"PreferencesDownUploads" bundle:nil];
	PrefsExamViewController *exam = [[PrefsExamViewController alloc] initWithNibName:@"PreferencesExam" bundle:nil];
	PrefsApplicationsViewController *applications = [[PrefsApplicationsViewController alloc] initWithNibName:@"PreferencesApplications" bundle:nil];
	PrefsResourcesViewController *resources = [[PrefsResourcesViewController alloc] initWithNibName:@"PreferencesResources" bundle:nil];
	PrefsNetworkViewController *network = [[PrefsNetworkViewController alloc] initWithNibName:@"PreferencesNetwork" bundle:nil];
	PrefsSecurityViewController *security = [[PrefsSecurityViewController alloc] initWithNibName:@"PreferencesSecurity" bundle:nil];
	[[MBPreferencesController sharedController] setModules:[NSArray arrayWithObjects:general, self.SEBConfigVC, appearance, browser, downuploads, exam, applications, resources, network, security, nil]];
//	[[MBPreferencesController sharedController] setModules:[NSArray arrayWithObjects:general, config, appearance, browser, downuploads, exam, applications, network, security, nil]];
    // Set self as the window delegate to be able to post a notification when preferences window is closing
    // will be overridden when the general pane is displayed (loaded from nib)
    if (![[MBPreferencesController sharedController].window delegate]) {
        // Set delegate only if it's not yet set!
        [[MBPreferencesController sharedController].window setDelegate:self];
#ifdef DEBUG
        NSLog(@"Set PreferencesController as delegate for preferences window");
#endif
    }
}


- (void)releasePreferencesWindow
{
//    self.SEBConfigVC.preferencesController = nil;
//    self.SEBConfigVC = nil;
    self.refreshingPreferences = true;
    [[MBPreferencesController sharedController] unloadNibs];
}


- (void) setConfigFileCredentials
{
    [self.SEBConfigVC setSettingsPassword:_currentConfigPassword isHash:_currentConfigPasswordIsHash];
    [self.SEBConfigVC setCurrentConfigFileKeyRef:_currentConfigKeyRef];
}


// Stores current settings in memory (before editing them)
- (void) storeCurrentSettings
{
    // Store key/values from local or private UserDefaults
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    _settingsBeforeEditing = [preferences dictionaryRepresentationSEB];
    // Store current flag for private/local client settings
    _userDefaultsPrivateBeforeEditing = NSUserDefaults.userDefaultsPrivate;
    // Store current config URL
    _configURLBeforeEditing = [[MyGlobals sharedMyGlobals] currentConfigURL];
    // Store current Browser Exam Key
    _browserExamKeyBeforeEditing = [preferences secureObjectForKey:@"org_safeexambrowser_currentData"];
}


// Restores settings which were stored in memory before editing
- (void) restoreStoredSettings
{
    SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
    // If config mode changed (private/local client settings), then switch to the mode active before
    if (_userDefaultsPrivateBeforeEditing != NSUserDefaults.userDefaultsPrivate) {
        [NSUserDefaults setUserDefaultsPrivate:_userDefaultsPrivateBeforeEditing];
    }
    [configFileManager storeIntoUserDefaults:_settingsBeforeEditing];
    // Set the original settings title in the preferences window
    [[MyGlobals sharedMyGlobals] setCurrentConfigURL:_configURLBeforeEditing];
}


// Check if settings have changed
- (BOOL) settingsChanged
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    return ![_browserExamKeyBeforeEditing isEqualToData:[preferences secureObjectForKey:@"org_safeexambrowser_currentData"]];
}


#pragma mark -
#pragma mark IBActions: Methods for opening, saving, reverting and using edited settings

- (IBAction) openSEBPrefs:(id)sender {
    // Set the default name for the file and show the panel.
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    //[panel setNameFieldStringValue:newName];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"seb"]];
    [panel beginSheetModalForWindow:[MBPreferencesController sharedController].window
                  completionHandler:^(NSInteger result){
                      if (result == NSFileHandlingPanelOKButton)
                      {
                          NSURL *sebFileURL = [panel URL];
                          
//                          // Check if private UserDefauls are switched on already
//                          if (NSUserDefaults.userDefaultsPrivate) {
//                          }
                          
#ifdef DEBUG
                          NSLog(@"Loading .seb settings file with file URL %@", sebFileURL);
#endif
                          NSError *error = nil;
                          NSData *sebData = [NSData dataWithContentsOfURL:sebFileURL options:nil error:&error];
                          
                          if (error) {
                              // Error when reading configuration data
                              [NSApp presentError:error];
                          } else {
                              SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
                              
                              // Decrypt and store the .seb config file
                              if ([configFileManager storeDecryptedSEBSettings:sebData forEditing:YES]) {
                                  // if successfull save the path to the file for possible editing in the preferences window
                                  [[MyGlobals sharedMyGlobals] setCurrentConfigURL:sebFileURL];
                                  
                                  [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
                                  [[MBPreferencesController sharedController] showWindow:sender];
                                  
                                  //[self requestedRestart:nil];
                              }
                          }
                      }
                  }];
    
}


// Action saving current preferences to a .seb file choosing the filename
- (IBAction) saveSEBPrefs:(id)sender
{
    [self savePrefsAs:NO];
}


// Action saving current preferences to a .seb file choosing the filename
- (IBAction) saveSEBPrefsAs:(id)sender
{
    [self savePrefsAs:YES];
}


// Method which encrypts and saves current preferences to an encrypted .seb file
- (void) savePrefsAs:(BOOL)saveAs
{
    // Get selected config purpose
    sebConfigPurposes configPurpose = [self.SEBConfigVC getSelectedConfigPurpose];
    
    // Read SEB settings from UserDefaults and encrypt them using the provided security credentials
    NSData *encryptedSebData = [self.SEBConfigVC encryptSEBSettingsWithSelectedCredentials];
    
    // If SEB settings were actually read and encrypted we save them
    if (encryptedSebData) {
        NSURL *currentConfigFileURL;
        // Check if local client settings (UserDefauls) are active
        if (!NSUserDefaults.userDefaultsPrivate) {
            // Update the Browser Exam Key without re-generating its salt
            [[SEBCryptor sharedSEBCryptor] updateEncryptedUserDefaultsNewSalt:NO];
            
            // Preset "SebClientSettings.seb" as default file name
            currentConfigFileURL = [NSURL URLWithString:@"SebClientSettings.seb"];
        } else {
            // When we're not saving local client settings, then we update the Browser Exam Key with a new salt
            [[SEBCryptor sharedSEBCryptor] updateEncryptedUserDefaultsNewSalt:YES];
            
            // Get the current filename
            //            filename = [[MyGlobals sharedMyGlobals] currentConfigPath].lastPathComponent;
            currentConfigFileURL = [[MyGlobals sharedMyGlobals] currentConfigURL];
            //            if ([[MyGlobals sharedMyGlobals] currentConfigPath]) {
            //            }
        }
        if (!saveAs && [currentConfigFileURL isFileURL]) {
            // "Save": Rewrite the file openend before
            NSError *error;
            if (![encryptedSebData writeToURL:currentConfigFileURL options:NSDataWritingAtomic error:&error]) {
                // If the prefs file couldn't be written to app bundle
                NSRunAlertPanel(NSLocalizedString(@"Writing Settings Failed", nil),
                                NSLocalizedString(@"Make sure you have write permissions in the chosen directory", nil),
                                NSLocalizedString(@"OK", nil), nil, nil);
            } else {
                [[MyGlobals sharedMyGlobals] setCurrentConfigURL:currentConfigFileURL];
                [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
                [[MBPreferencesController sharedController] setPreferencesWindowTitle];
            }
            
        } else {
            // "Save As": Set the default name and if there is an existing path for the file and show the panel.
            NSSavePanel *panel = [NSSavePanel savePanel];
            NSURL *directory = currentConfigFileURL.URLByDeletingLastPathComponent;
            NSString *directoryString = directory.relativePath;
            if ([directoryString isEqualToString:@"."]) {
                NSFileManager *fileManager = [NSFileManager new];
                directory = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
            }
            [panel setDirectoryURL:directory];
            [panel setNameFieldStringValue:currentConfigFileURL.lastPathComponent];
            [panel setAllowedFileTypes:[NSArray arrayWithObject:@"seb"]];
            [panel beginSheetModalForWindow:[MBPreferencesController sharedController].window
                          completionHandler:^(NSInteger result){
                              if (result == NSFileHandlingPanelOKButton)
                              {
                                  NSURL *prefsFileURL = [panel URL];
                                  NSError *error;
                                  // Write the contents in the new format.
                                  if (![encryptedSebData writeToURL:prefsFileURL options:NSDataWritingAtomic error:&error]) {
                                      //if (![filteredPrefsDict writeToURL:prefsFileURL atomically:YES]) {
                                      // If the prefs file couldn't be written to app bundle
                                      NSRunAlertPanel(NSLocalizedString(@"Writing Settings Failed", nil),
                                                      NSLocalizedString(@"Make sure you have write permissions in the chosen directory", nil),
                                                      NSLocalizedString(@"OK", nil), nil, nil);
                                  } else {
                                      // Prefs got successfully written to file
                                      // If "Save As" or the last file didn't had a full path (wasn't stored on drive):
                                      // Store the new path as the current config file path
                                      if (saveAs || ![currentConfigFileURL isFileURL]) {
                                          [[MyGlobals sharedMyGlobals] setCurrentConfigURL:panel.URL];
                                          [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
                                      }
                                      [[MBPreferencesController sharedController] setPreferencesWindowTitle];
                                      NSString *settingsSavedMessage = configPurpose ? NSLocalizedString(@"Settings have been saved, use this file to reconfigure local settings of a SEB client.", nil) : NSLocalizedString(@"Settings have been saved, use this file to start the exam with SEB.", nil);
                                      NSRunAlertPanel(NSLocalizedString(@"Writing Settings Succeeded", nil), @"%@", NSLocalizedString(@"OK", nil), nil, nil,settingsSavedMessage);
                                  }
                              }
                          }];
        }
    }
}


// Action reverting preferences to default settings
- (IBAction) revertToDefaultSettings:(id)sender
{
    // Reset the config file password
    _currentConfigPassword = nil;
    _currentConfigPasswordIsHash = NO;
    // Reset the config file encrypting identity (key) reference
    _currentConfigKeyRef = nil;
    // Reset the settings password and confirm password fields and the identity popup menu
    [self.SEBConfigVC resetSettingsPasswordFields];
    // Reset the settings identity popup menu
    [self.SEBConfigVC resetSettingsIdentity];
    
    // If using private defaults
    if (NSUserDefaults.userDefaultsPrivate) {
        // Release preferences window so bindings get synchronized properly with the new loaded values
        [self releasePreferencesWindow];
    }
    
    // Get default SEB settings
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultSettings = [preferences sebDefaultSettings];
    
    // Write values from .seb config file to the local preferences (shared UserDefaults)
    SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
    [configFileManager storeIntoUserDefaults:defaultSettings];
    
    [[SEBCryptor sharedSEBCryptor] updateEncryptedUserDefaultsNewSalt:YES];
    
    // If using private defaults
    if (NSUserDefaults.userDefaultsPrivate) {
        // Re-initialize and open preferences window
        [self initPreferencesWindow];
        [[MBPreferencesController sharedController] showWindow:sender];
    }
}


// Action reverting preferences to local client settings
- (IBAction) revertToLocalClientSettings:(id)sender
{
    // Release preferences window so buttons get enabled properly for the local client settings mode
    [self releasePreferencesWindow];
    
    //switch to system's UserDefaults
    [NSUserDefaults setUserDefaultsPrivate:NO];
    
    // Get key/values from local shared client UserDefaults
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSDictionary *localClientPreferences = [preferences dictionaryRepresentationSEB];
    
    // Reset the config file password
    _currentConfigPassword = nil;
    _currentConfigPasswordIsHash = NO;
    // Reset the config file encrypting identity (key) reference
    _currentConfigKeyRef = nil;
    
    // Write values from local to private preferences
    SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
    [configFileManager storeIntoUserDefaults:localClientPreferences];
    
    [[SEBCryptor sharedSEBCryptor] updateEncryptedUserDefaultsNewSalt:NO];
    
    [[MyGlobals sharedMyGlobals] setCurrentConfigURL:nil];
    
    [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
    [[MBPreferencesController sharedController] setPreferencesWindowTitle];
    
    // Re-initialize and open preferences window
    [self initPreferencesWindow];
    [[MBPreferencesController sharedController] showWindow:sender];
}


// Action reverting preferences to the last saved or opend file
- (IBAction) revertToLastSaved:(id)sender
{
    SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
    // If using private user defaults
    if (NSUserDefaults.userDefaultsPrivate) {
#ifdef DEBUG
        NSLog(@"Reverting private settings to last saved or opened .seb file");
#endif
        NSError *error = nil;
        NSData *sebData = [NSData dataWithContentsOfURL:[[MyGlobals sharedMyGlobals] currentConfigURL] options:nil error:&error];
        
        if (error) {
            // Error when reading configuration data
            [NSApp presentError:error];
        } else {
            // Decrypt and store the .seb config file
            if ([configFileManager storeDecryptedSEBSettings:sebData forEditing:YES]) {
                
                [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
                [[MBPreferencesController sharedController] showWindow:sender];
                
                //[self requestedRestart:nil];
            }
        }
    } else {
        // If using local client settings
#ifdef DEBUG
        NSLog(@"Reverting local client settings to settings before editing");
#endif
        [configFileManager storeIntoUserDefaults:_settingsBeforeEditing];
    }
}


// Action duplicating current preferences for editing
- (IBAction) editDuplicate:(id)sender
{
    // Release preferences window so bindings get synchronized properly with the new loaded values
    [self releasePreferencesWindow];
    
    // If using private defaults
    if (NSUserDefaults.userDefaultsPrivate) {
        // Add string " copy" (or " n+1" if the filename already ends with " copy" or " copy n")
        // to the config name filename
        // Get the current config file full path
//        NSString *currentConfigFilePath = [[[MyGlobals sharedMyGlobals] currentConfigPath] stringByRemovingPercentEncoding];
        NSURL *currentConfigFilePath = [[MyGlobals sharedMyGlobals] currentConfigURL];
        // Get the filename without extension
        NSString *filename = currentConfigFilePath.lastPathComponent.stringByDeletingPathExtension;
        // Get the extension (should be .seb)
        NSString *extension = currentConfigFilePath.pathExtension;
        if (filename.length == 0) {
            filename = NSLocalizedString(@"untitled", @"untitled filename");
            extension = @".seb";
        } else {
            NSRange copyStringRange = [filename rangeOfString:NSLocalizedString(@" copy", @"word indicating the duplicate of a file, same as in Finder ' copy'") options:NSBackwardsSearch];
            if (copyStringRange.location == NSNotFound) {
                filename = [filename stringByAppendingString:NSLocalizedString(@" copy", nil)];
            } else {
                NSString *copyNumberString = [filename substringFromIndex:copyStringRange.location+copyStringRange.length];
                if (copyNumberString.length == 0) {
                    filename = [filename stringByAppendingString:NSLocalizedString(@" 1", nil)];
                } else {
                    NSInteger copyNumber = [[copyNumberString substringFromIndex:1] integerValue];
                    if (copyNumber == 0) {
                        filename = [filename stringByAppendingString:NSLocalizedString(@" copy", nil)];
                    } else {
                        filename = [[filename substringToIndex:copyStringRange.location+copyStringRange.length+1] stringByAppendingString:[NSString stringWithFormat:@"%ld", copyNumber+1]];
                    }
                }
            }
        }
        [[MyGlobals sharedMyGlobals] setCurrentConfigURL:[[[currentConfigFilePath URLByDeletingLastPathComponent] URLByAppendingPathComponent:filename] URLByAppendingPathExtension:extension]];
    } else {
        // If using local defaults
        [[MyGlobals sharedMyGlobals] setCurrentConfigURL:[NSURL URLWithString:@"SebClientSettings.seb"]];
        
        // Get key/values from local shared client UserDefaults
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        NSDictionary *localClientPreferences = [preferences dictionaryRepresentationSEB];

        // Switch to private UserDefaults (saved non-persistantly in memory instead in ~/Library/Preferences)
        NSMutableDictionary *privatePreferences = [NSUserDefaults privateUserDefaults]; //the mutable dictionary has to be created here, otherwise the preferences values will not be saved!
        [NSUserDefaults setUserDefaultsPrivate:YES];
        
        SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
        [configFileManager storeIntoUserDefaults:localClientPreferences];
        
#ifdef DEBUG
        NSLog(@"Private preferences set: %@", privatePreferences);
#endif
    }
    // Set the new settings title in the preferences window
    [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
    [[MBPreferencesController sharedController] setPreferencesWindowTitle];

    // Re-initialize and open preferences window
    [self initPreferencesWindow];
    [[MBPreferencesController sharedController] showWindow:sender];
}


// Action configuring client with currently edited preferences
- (IBAction) configureClient:(id)sender
{
    // Get key/values from private UserDefaults
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSDictionary *privatePreferences = [preferences dictionaryRepresentationSEB];
    
    // Release preferences window so buttons get enabled properly for the local client settings mode
    [self releasePreferencesWindow];
    
    //switch to system's UserDefaults
    [NSUserDefaults setUserDefaultsPrivate:NO];
    
    // Write values from .seb config file to the local preferences (shared UserDefaults)
    SEBConfigFileManager *configFileManager = [[SEBConfigFileManager alloc] init];
    [configFileManager storeIntoUserDefaults:privatePreferences];
    
    [[SEBCryptor sharedSEBCryptor] updateEncryptedUserDefaultsNewSalt:NO];
    
    [[MyGlobals sharedMyGlobals] setCurrentConfigURL:nil];
    
    [[MBPreferencesController sharedController] setSettingsFileURL:[[MyGlobals sharedMyGlobals] currentConfigURL]];
    [[MBPreferencesController sharedController] setPreferencesWindowTitle];

    // Re-initialize and open preferences window
    [self initPreferencesWindow];
    [[MBPreferencesController sharedController] showWindow:sender];
}


// Action applying currently edited preferences, closing preferences window and restarting SEB
- (IBAction) applyAndRestartSEB:(id)sender
{
    [[MBPreferencesController sharedController].window orderOut:self];
    [[NSApplication sharedApplication] stopModal];
    // Post a notification that it was requested to restart SEB with changed settings
	[[NSNotificationCenter defaultCenter]
     postNotificationName:@"requestRestartNotification" object:self];
}


@end
