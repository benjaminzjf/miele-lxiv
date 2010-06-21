/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "DicomStudy.h"
#import "DicomSeries.h"
#import "DicomImage.h"
#import "DicomAlbum.h"
#import <OsiriX/DCMAbstractSyntaxUID.h>
#import <OsiriX/DCM.h>
#import "MutableArrayCategory.h"
#import "SRAnnotation.h"

#ifdef OSIRIX_VIEWER
#import "DCMPix.h"
#import "VRController.h"
#import "browserController.h"
#import "BonjourBrowser.h"
#import "DicomFileDCMTKCategory.h"
#import "DICOMToNSString.h"
#import "XMLControllerDCMTKCategory.h"
#import "Notifications.h"
#endif

#define WBUFSIZE 512

NSString* soundex4( NSString *inString)
{
	char *p, *p1;
	char *outstr;
	int i;
	char workbuf[WBUFSIZE + 1];
	char priorletter;
	int N;
	
	if( inString == nil) return nil;
	
      /* Make a working copy  */
	
      strncpy(workbuf, [[inString uppercaseString] UTF8String], WBUFSIZE);
      workbuf[WBUFSIZE] = 0;
	  
      /* Convert all vowels to 'A'  */

      for (p = workbuf; *p; ++p)
      {
            if (strchr("AEIOUY", *p))
                  *p = 'A';
      }

      /* Prefix transformations: done only once on the front of a name */

      if ( 0 == strncmp(workbuf, "MAC", 3))     /* MAC to MCC    */
            workbuf[1] = 'C';
      else if ( 0 == strncmp(workbuf, "KN", 2)) /* KN to NN      */
            workbuf[0] = 'N';
      else if ('K' == workbuf[0])                     /* K to C        */
            workbuf[0] = 'C';
      else if ( 0 == strncmp(workbuf, "PF", 2)) /* PF to FF      */
            workbuf[0] = 'F';
      else if ( 0 == strncmp(workbuf, "SCH", 3))/* SCH to SSS    */
            workbuf[1] = workbuf[2] = 'S';

      /*
      ** Infix transformations: done after the first letter,
      ** left to right
      */

      while ((p = strstr(workbuf, "DG")) > workbuf)   /* DG to GG      */
            p[0] = 'G';
      while ((p = strstr(workbuf, "CAAN")) > workbuf) /* CAAN to TAAN  */
            p[0] = 'T';
      while ((p = strchr(workbuf, 'D')) > workbuf)    /* D to T        */
            p[0] = 'T';
      while ((p = strstr(workbuf, "NST")) > workbuf)  /* NST to NSS    */
            p[2] = 'S';
      while ((p = strstr(workbuf, "AV")) > workbuf)   /* AV to AF      */
            p[1] = 'F';
      while ((p = strchr(workbuf, 'Q')) > workbuf)    /* Q to G        */
            p[0] = 'G';
      while ((p = strchr(workbuf, 'Z')) > workbuf)    /* Z to S        */
            p[0] = 'S';
      while ((p = strchr(workbuf, 'M')) > workbuf)    /* M to N        */
            p[0] = 'N';
      while ((p = strstr(workbuf, "KN")) > workbuf)   /* KN to NN      */
            p[0] = 'N';
      while ((p = strchr(workbuf, 'K')) > workbuf)    /* K to C        */
            p[0] = 'C';
      while ((p = strstr(workbuf, "AH")) > workbuf)   /* AH to AA      */
            p[1] = 'A';
      while ((p = strstr(workbuf, "HA")) > workbuf)   /* HA to AA      */
            p[0] = 'A';
      while ((p = strstr(workbuf, "AW")) > workbuf)   /* AW to AA      */
            p[1] = 'A';
      while ((p = strstr(workbuf, "PH")) > workbuf)   /* PH to FF      */
            p[0] = p[1] = 'F';
      while ((p = strstr(workbuf, "SCH")) > workbuf)  /* SCH to SSS    */
            p[0] = p[1] = 'S';

      /*
      ** Suffix transformations: done on the end of the word,
      ** right to left
      */

      /* (1) remove terminal 'A's and 'S's      */

      for (i = strlen(workbuf) - 1;
            (i > 0) && ('A' == workbuf[i] || 'S' == workbuf[i]);
            --i)
      {
            workbuf[i] = 0;
      }

      /* (2) terminal NT to TT      */

      for (i = strlen(workbuf) - 1;
            (i > 1) && ('N' == workbuf[i - 1] || 'T' == workbuf[i]);
            --i)
      {
            workbuf[i - 1] = 'T';
      }

      /* Now strip out all the vowels except the first     */

      p = p1 = workbuf;
      while ( 0 != (*p1++ = *p++))
      {
            while ('A' == *p)
                  ++p;
      }

      /* Remove all duplicate letters     */

      p = p1 = workbuf;
      priorletter = 0;
      do {
            while (*p == priorletter)
                  ++p;
            priorletter = *p;
      } while (0 != (*p1++ = *p++));

      /* Finish up */
	
	  return [NSString stringWithUTF8String: workbuf];
}

@implementation DicomStudy

@dynamic accessionNumber;
@dynamic comment;
@dynamic date;
@dynamic dateAdded;
@dynamic dateOfBirth;
@dynamic dateOpened;
@dynamic dictateURL;
@dynamic expanded;
@dynamic hasDICOM;
@dynamic id;
@dynamic institutionName;
@dynamic lockedStudy;
@dynamic modality;
@dynamic name;
@dynamic numberOfImages;
@dynamic patientID;
@dynamic patientSex;
@dynamic patientUID;
@dynamic performingPhysician;
@dynamic referringPhysician;
@dynamic reportURL;
@dynamic stateText;
@dynamic studyInstanceUID;
@dynamic studyName;
@dynamic windowsState;
@dynamic albums;
@dynamic series;

static NSRecursiveLock *dbModifyLock = nil;

+ (NSRecursiveLock*) dbModifyLock
{
	if( dbModifyLock == nil)
		dbModifyLock = [[NSRecursiveLock alloc] init];
		
	return dbModifyLock;
}

+ (NSString*) soundex: (NSString*) s
{
	NSArray *a = [s componentsSeparatedByString:@" "];
	NSMutableString *r = [NSMutableString string];
	
	for( NSString *w in a)
		[r appendFormat:@" %@", soundex4( w)];
	
	return r;
}

- (void) reapplyAnnotationsFromDICOMSR
{
	#ifndef OSIRIX_LIGHT
	if( [self.hasDICOM boolValue] == YES)
	{
		[[self managedObjectContext] lock];
		
		@try
		{
			NSManagedObject *archivedAnnotations = [self annotationsSRImage];
			NSString *dstPath = [archivedAnnotations valueForKey: @"completePath"];
			
			if( dstPath)
			{
				SRAnnotation *r = [[[SRAnnotation alloc] initWithContentsOfFile: dstPath] autorelease];
				
				NSDictionary *annotations = [r annotations];
				if( annotations)
					[self applyAnnotationsFromDictionary: annotations];
			}
		}
		@catch (NSException * e) 
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
		
		[[self managedObjectContext] unlock];
	}
	#endif
}

- (void) applyAnnotationsFromDictionary: (NSDictionary*) rootDict
{
	if( [self.studyInstanceUID isEqualToString: [rootDict valueForKey: @"studyInstanceUID"]] == NO || [self.patientUID isEqualToString: [rootDict valueForKey: @"patientUID"]] == NO)
	{
		NSLog( @"******** WARNING applyAnnotationsFromDictionary will not be applied - studyInstanceUID / name / patientID are NOT corresponding: %@ %@", [rootDict valueForKey: @"name"], self.name);
	}
	else
	{
		@try
		{
			// We are at root level
			[self setPrimitiveValue: [rootDict valueForKey: @"comment"] forKey: @"comment"];
			[self setPrimitiveValue: [rootDict valueForKey: @"stateText"] forKey: @"stateText"];
			
			NSArray *albums = [BrowserController albumsInContext: [self managedObjectContext]];
			
			for( NSString *name in [rootDict valueForKey: @"albums"])
			{
				NSUInteger index = [[albums valueForKey: @"name"] indexOfObject: name];
				
				if( index != NSNotFound)
				{
					if( [[[albums objectAtIndex: index] valueForKey: @"smartAlbum"] boolValue] == NO)
					{
						NSMutableSet *studies = [[albums objectAtIndex: index] mutableSetValueForKey: @"studies"];	
						
						[studies addObject: self];
					}
				}
			}
			
			NSArray *seriesArray = [[self valueForKey: @"series"] allObjects];
			
			NSArray *allImages = nil, *compressedSopInstanceUIDArray = nil;
			
			for( NSDictionary *series in [rootDict valueForKey: @"series"])
			{
				// -------------------------
				// Find corresponding series
				NSUInteger index = [[seriesArray valueForKey: @"seriesInstanceUID"] indexOfObject: [series valueForKey: @"seriesInstanceUID"]];
				
				if( index == NSNotFound)
					index = [[seriesArray valueForKey: @"seriesDICOMUID"] indexOfObject: [series valueForKey: @"seriesDICOMUID"]];
				
				if( index != NSNotFound)
				{
					DicomSeries *s = [seriesArray objectAtIndex: index];
					
					if( [series valueForKey:@"comment"])
						[s setValue: [series valueForKey:@"comment"] forKey: @"comment"];
				
					if( [series valueForKey:@"stateText"])
						[s setValue: [series valueForKey:@"stateText"] forKey: @"stateText"];
					
					for( NSDictionary *image in [series valueForKey: @"images"])
					{
						if( allImages == nil)
						{
							allImages = [NSArray array];
							for( id w in seriesArray)
								allImages = [allImages arrayByAddingObjectsFromArray: [[w valueForKey: @"images"] allObjects]];
								
							compressedSopInstanceUIDArray = [allImages filteredArrayUsingPredicate: [NSPredicate predicateWithFormat:@"compressedSopInstanceUID != NIL"]];
						}
						
						NSPredicate	*predicate = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForKeyPath: @"compressedSopInstanceUID"] rightExpression: [NSExpression expressionForConstantValue: [DicomImage sopInstanceUIDEncodeString: [image valueForKey: @"sopInstanceUID"]]] customSelector: @selector( isEqualToSopInstanceUID:)];
						NSArray	*found = [compressedSopInstanceUIDArray filteredArrayUsingPredicate: predicate];
				
						// -------------------------
						// Find corresponding image
						if( [found count] > 0)
						{
							DicomImage *i = [found lastObject];
							
							if( [image valueForKey:@"isKeyImage"])
								[i setValue: [image valueForKey:@"isKeyImage"] forKey: @"isKeyImage"];
						}
						else NSLog( @"----- applyAnnotationsFromDictionary : image not found");
					}
				}
				else NSLog( @"----- applyAnnotationsFromDictionary : series not found");
			}
		}
		@catch (NSException * e)
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
	}
}

- (NSDictionary*) annotationsAsDictionary
{
	// Comments - Study / Series
	
	// State - Study / Series
	
	// Albums - Study
	
	// Key Images - Image
	
	// ***************************************************************************************************
	
	// Study Level
	
	NSMutableDictionary *rootDict = [NSMutableDictionary dictionary];
	
	if( [self valueForKey:@"studyInstanceUID"])
		[rootDict setObject: [self valueForKey:@"studyInstanceUID"] forKey: @"studyInstanceUID"];
	
	if( [self valueForKey:@"name"])
		[rootDict setObject: [self valueForKey:@"name"] forKey: @"patientsName"];
	
	if( [self valueForKey:@"patientID"])
		[rootDict setObject: [self valueForKey:@"patientID"] forKey: @"patientID"];
	
	if( [self valueForKey:@"patientUID"])
		[rootDict setObject: [self valueForKey:@"patientUID"] forKey: @"patientUID"];
	
	if( [self valueForKey:@"comment"])
		[rootDict setObject: [self valueForKey:@"comment"] forKey: @"comment"];
	
	if( [self valueForKey:@"stateText"])
		[rootDict setObject: [self valueForKey:@"stateText"] forKey: @"stateText"];
	
	NSMutableArray *albumsArray = [NSMutableArray array];
	
	for( DicomAlbum * a in [[self valueForKey: @"albums"] sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES] autorelease]]])
	{
		if( [[a valueForKey: @"smartAlbum"] boolValue] == NO)
		{
			NSString *name = [a valueForKey: @"name"];
			[albumsArray addObject: name];
		}
	}
	
	[rootDict setObject: albumsArray forKey: @"albums"];
	
	// ***************************************************************************************************
	
	// Series Level
	
	NSMutableArray *seriesArray = [NSMutableArray array];
	
	for( DicomSeries *series in [[self valueForKey: @"series"] sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: YES] autorelease]]])
	{
		NSMutableDictionary *seriesDict = [NSMutableDictionary dictionary];
		
		if( [series valueForKey:@"seriesInstanceUID"] && [series valueForKey:@"seriesDICOMUID"])
		{
			if( [series valueForKey:@"comment"])
				[seriesDict setObject: [series valueForKey:@"comment"] forKey: @"comment"];
			
			if( [series valueForKey:@"stateText"])
				[seriesDict setObject: [series valueForKey:@"stateText"] forKey: @"stateText"];
			
			// ***************************************************************************************************
			
			// Images Level
			
			NSMutableArray *imagesArray = [NSMutableArray array];
			for( DicomSeries *image in [[series valueForKey: @"images"] sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: YES] autorelease]]])
			{
				NSMutableDictionary *imageDict = [NSMutableDictionary dictionary];
				
				if( [image valueForKey:@"sopInstanceUID"])
				{
					if( [image valueForKey:@"storedIsKeyImage"])
					{
						[imageDict setObject: [image valueForKey:@"isKeyImage"] forKey: @"isKeyImage"];
						[imageDict setObject: [image valueForKey:@"sopInstanceUID"] forKey: @"sopInstanceUID"];
						[imagesArray addObject: imageDict];
					}
				}
			}
			
			if( [imagesArray count] > 0)
				[seriesDict setObject: imagesArray forKey: @"images"];
			
			if( [seriesDict count] > 0)
			{
				[seriesDict setObject: [series valueForKey:@"seriesInstanceUID"] forKey: @"seriesInstanceUID"];
				[seriesDict setObject: [series valueForKey:@"seriesDICOMUID"] forKey: @"seriesDICOMUID"];
				
				[seriesArray addObject: seriesDict];
			}
		}
	}
	
	if( [seriesArray count] > 0)
		[rootDict setObject: seriesArray forKey: @"series"];
	
	return rootDict;
}

- (void) archiveAnnotationsAsDICOMSR
{
	#ifndef OSIRIX_LIGHT
	if( [self.hasDICOM boolValue] == YES)
	{
		[[self managedObjectContext] lock];
		
		@try
		{
			NSManagedObject *archivedAnnotations = [self annotationsSRImage];
			NSString *dstPath = [archivedAnnotations valueForKey: @"completePath"];
			
			if( dstPath == nil)
				dstPath = [[BrowserController currentBrowser] getNewFileDatabasePath: @"dcm"];
			
			NSDictionary *annotationsDict = [self annotationsAsDictionary];
			
			// Save or Re-Save it as DICOM SR
			SRAnnotation *r = [[[SRAnnotation alloc] initWithDictionary: annotationsDict path: dstPath forImage: [[[[self valueForKey:@"series"] anyObject] valueForKey:@"images"] anyObject]] autorelease];
			[r writeToFileAtPath: dstPath];
			
			[BrowserController addFiles: [NSArray arrayWithObject: dstPath]
							  toContext: [self managedObjectContext]
							 toDatabase: [BrowserController currentBrowser]
							  onlyDICOM: YES 
					   notifyAddedFiles: YES
					parseExistingObject: YES
							   dbFolder: [[BrowserController currentBrowser] fixedDocumentsDirectory]
					  generatedByOsiriX: YES];
		}
		@catch (NSException * e) 
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
		
		[[self managedObjectContext] unlock];
	}
	#endif
}

- (void) archiveReportAsDICOMSR
{
	#ifndef OSIRIX_LIGHT
	if( [self.hasDICOM boolValue] == YES)
	{
		[[self managedObjectContext] lock];
		
		// Is there a report attached to this study -> archive it
		if( [self valueForKey: @"reportURL"])
		{
			@try
			{
				// Report
				if( [self valueForKey: @"reportURL"])
				{
					NSString *zippedFile = @"/tmp/zippedReport.zip";
					NSManagedObject *archivedReport = [self reportSRSeries];
					BOOL needToArchive = YES;
					NSString *dstPath = nil;
					
					dstPath = [[archivedReport valueForKeyPath: @"images.completePath"] anyObject];
					if( [[[archivedReport valueForKeyPath: @"images.completePath"] allObjects] count] > 1)
						NSLog( @"********* warning multiple report for this study");
						
					if( [[self valueForKey: @"reportURL"] hasPrefix: @"http://"] || [[self valueForKey: @"reportURL"] hasPrefix: @"https://"])
					{
						if( dstPath == nil)
							dstPath = [[BrowserController currentBrowser] getNewFileDatabasePath: @"dcm"];
						
						// Save or Re-Save it as DICOM SR
						SRAnnotation *r = [[[SRAnnotation alloc] initWithURLReport: [self valueForKey: @"reportURL"] path: dstPath forImage: [[[[self valueForKey:@"series"] anyObject] valueForKey:@"images"] anyObject]] autorelease];
						[r writeToFileAtPath: dstPath];
						
						[BrowserController addFiles: [NSArray arrayWithObject: dstPath]
										  toContext: [self managedObjectContext]
										 toDatabase: [BrowserController currentBrowser]
										  onlyDICOM: YES 
								   notifyAddedFiles: YES
								parseExistingObject: YES
										   dbFolder: [[BrowserController currentBrowser] fixedDocumentsDirectory]
								  generatedByOsiriX: YES];
					}
					else if( [[NSFileManager defaultManager] fileExistsAtPath: [self valueForKey: @"reportURL"]])
					{
						[BrowserController encryptFileOrFolder: [self valueForKey: @"reportURL"] inZIPFile: zippedFile password: nil deleteSource: NO showGUI: NO];
						
						if( [[NSFileManager defaultManager] fileExistsAtPath: zippedFile])
						{
							if( dstPath == nil)
								dstPath = [[BrowserController currentBrowser] getNewFileDatabasePath: @"dcm"];
							else
							{
								SRAnnotation *r = [[[SRAnnotation alloc] initWithContentsOfFile: dstPath] autorelease];
								
								if( [[NSData dataWithContentsOfFile: zippedFile] isEqualToData: [r dataEncapsulated]])
									needToArchive = NO;
							}

							if( needToArchive)
							{
								// Save or Re-Save it as DICOM SR
								SRAnnotation *r = [[[SRAnnotation alloc] initWithFileReport: zippedFile path: dstPath forImage: [[[[self valueForKey:@"series"] anyObject] valueForKey:@"images"] anyObject]] autorelease];
								[r writeToFileAtPath: dstPath];
								
								[BrowserController addFiles: [NSArray arrayWithObject: dstPath]
												  toContext: [self managedObjectContext]
												 toDatabase: [BrowserController currentBrowser]
												  onlyDICOM: YES 
										   notifyAddedFiles: YES
										parseExistingObject: YES
												   dbFolder: [[BrowserController currentBrowser] fixedDocumentsDirectory]
										  generatedByOsiriX: YES];
							}
						}
					}
				}
			}
			@catch (NSException * e) 
			{
				NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
			}
		}
		else
		{
			@try
			{
				// Delete the existing Report
				if( [self reportSRSeries])
					[[BrowserController currentBrowser] proceedDeleteObjects: [[[self reportSRSeries] valueForKey: @"images"] allObjects]];
			}
			@catch (NSException * e) 
			{
				NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
			}
		}
		
		[[self managedObjectContext] unlock];
	}
	#endif
}

- (NSString*) soundex
{
	return [DicomStudy soundex: [self primitiveValueForKey: @"name"]];
}

- (NSString*) modalities
{
	NSString *m = nil;
	
	[[self managedObjectContext] lock];
	
	@try 
	{
		NSArray *seriesModalities = [[[self valueForKey:@"series"] allObjects] valueForKey:@"modality"];
		
		NSMutableArray *r = [NSMutableArray array];
		
		BOOL SC = NO, SR = NO, PR = NO;
		
		for( NSString *mod in seriesModalities)
		{
			if( [mod isEqualToString:@"SR"])
				SR = YES;
			else if( [mod isEqualToString:@"SC"])
				SC = YES;
			else if( [mod isEqualToString:@"PR"])
				PR = YES;
			else if( [mod isEqualToString:@"RTSTRUCT"] == YES && [r containsString: mod] == NO)
				[r addObject: @"RT"];
			else if( [mod isEqualToString:@"KO"])
			{
			}
			else if([r containsString: mod] == NO)
				[r addObject: mod];
		}
		
		if( [r count] == 0)
		{
			if( SC) [r addObject: @"SC"];
			else
			{
				if( SR) [r addObject: @"SR"];
				if( PR) [r addObject: @"PR"];
			}
		}
		
		m = [r componentsJoinedByString:@"\\"];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
		
	[[self managedObjectContext] unlock];
	
	return m;
}

- (void) dealloc
{
	[dicomTime release];
	
	[super dealloc];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
}

- (BOOL) isHidden;
{
	return isHidden;
}

- (void) setHidden: (BOOL) h;
{
	isHidden = h;
}

- (NSString*) type
{
	return @"Study";
}

- (void) dcmodifyThread: (NSDictionary*) dict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[[DicomStudy dbModifyLock] lock];
	
	#ifdef OSIRIX_VIEWER
	#ifndef OSIRIX_LIGHT
	@try 
	{
		NSMutableArray	*params = [NSMutableArray arrayWithObjects:@"dcmodify", @"--ignore-errors", nil];
		
		if( [dict objectForKey: @"value"] == nil || [(NSString*)[dict objectForKey: @"value"] length] == 0)
			[params addObjectsFromArray: [NSArray arrayWithObjects: @"-e", [dict objectForKey: @"field"], nil]];
		else
			[params addObjectsFromArray: [NSArray arrayWithObjects: @"-i", [NSString stringWithFormat: @"%@=%@", [dict objectForKey: @"field"], [dict objectForKey: @"value"]], nil]];
		
		NSMutableArray *files = [NSMutableArray arrayWithArray: [dict objectForKey: @"files"]];
		
		if( files)
		{
			[files removeDuplicatedStrings];
			
			[params addObjectsFromArray: files];
			
			@try
			{
				NSStringEncoding encoding = [NSString encodingForDICOMCharacterSet: [[DicomFile getEncodingArrayForFile: [files lastObject]] objectAtIndex: 0]];
				
				[XMLController modifyDicom: params encoding: encoding];
				
				for( id loopItem in files)
					[[NSFileManager defaultManager] removeFileAtPath: [loopItem stringByAppendingString:@".bak"] handler:nil];
			}
			@catch (NSException * e)
			{
				NSLog(@"**** DicomStudy setComment: %@", e);
			}
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	#endif
	#endif
	
	[[DicomStudy dbModifyLock] unlock];
	
	[pool release];
}

- (void) setComment: (NSString*) c
{
	if( [self.hasDICOM boolValue] == YES && [[NSUserDefaults standardUserDefaults] boolForKey: @"savedCommentsAndStatusInDICOMFiles"])
	{
		if( c == nil)
			c = @"";
			
		if( ([(NSString*)[self primitiveValueForKey: @"comment"] length] != 0 || [c length] != 0))
		{
			if( [c isEqualToString: [self primitiveValueForKey: @"comment"]] == NO)
			{
				NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: [[self paths] allObjects], @"files", @"(0032,4000)", @"field", c, @"value", nil];
				[NSThread detachNewThreadSelector: @selector( dcmodifyThread:) toTarget: self withObject: dict];
			}
		}
	}
	
	NSString *previousValue = [self primitiveValueForKey: @"comment"];
	
	[self willChangeValueForKey: @"comment"];
	[self setPrimitiveValue: c forKey: @"comment"];
	[self didChangeValueForKey: @"comment"];
	
	if( [previousValue length] != 0 || [c length] != 0)
	{
		if( [c isEqualToString: previousValue] == NO)
			[self archiveAnnotationsAsDICOMSR];
	}
}

- (void) setStateText: (NSNumber*) c
{
	#ifdef OSIRIX_VIEWER
	#ifndef OSIRIX_LIGHT
	@try 
	{
		if( [self.hasDICOM boolValue] == YES && [[NSUserDefaults standardUserDefaults] boolForKey: @"savedCommentsAndStatusInDICOMFiles"])
		{
			if( c == nil)
				c = [NSNumber numberWithInt: 0];
			
			if( [c intValue] != [[self primitiveValueForKey: @"stateText"] intValue])
			{
				NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: [[self paths] allObjects], @"files", @"(4008,0212)", @"field", [c stringValue], @"value", nil];
				[NSThread detachNewThreadSelector: @selector( dcmodifyThread:) toTarget: self withObject: dict];
			}
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	#endif
	#endif
	
	NSNumber *previousState = [self primitiveValueForKey: @"stateText"];
	
	[self willChangeValueForKey: @"stateText"];
	[self setPrimitiveValue: c forKey: @"stateText"];
	[self didChangeValueForKey: @"stateText"];
	
	if( [c intValue] != [previousState intValue])
		[self archiveAnnotationsAsDICOMSR];
}

- (void) setReportURL: (NSString*) url
{
	#ifdef OSIRIX_VIEWER
	BrowserController	*cB = [BrowserController currentBrowser];
	
	if( url && [cB isCurrentDatabaseBonjour] == NO)
	{
		if( [url hasPrefix: @"http://"] == NO && [url hasPrefix: @"https://"] == NO)
		{
		   NSString *commonPath = [[cB fixedDocumentsDirectory] commonPrefixWithString: url options: NSLiteralSearch];
		
			if( [commonPath isEqualToString: [cB fixedDocumentsDirectory]])
			{
				url = [url substringFromIndex: [[cB fixedDocumentsDirectory] length]];
			
				if( [url characterAtIndex: 0] == '/') url = [url substringFromIndex: 1];
			}
		}
	}
	#endif
	
	[self willChangeValueForKey: @"reportURL"];
	[self setPrimitiveValue: url forKey: @"reportURL"];
	[self didChangeValueForKey: @"reportURL"];
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"archiveReportsAndAnnotationsAsDICOMSR"])
		[self archiveReportAsDICOMSR];
}

- (NSString*) reportURL
{
	NSString *url = [self primitiveValueForKey: @"reportURL"];
	
	#ifdef OSIRIX_VIEWER
	if( url && [url length])
	{
		if( [url hasPrefix: @"http://"] == NO && [url hasPrefix: @"https://"] == NO)
		{
			BrowserController	*cB = [BrowserController currentBrowser];
			
			if( [cB isCurrentDatabaseBonjour] == NO)
			{
				if( [url characterAtIndex: 0] != '/')
					url = [[cB fixedDocumentsDirectory] stringByAppendingPathComponent: url];
				else
				{	// Should we convert it to a local path?
					NSString *commonPath = [[cB fixedDocumentsDirectory] commonPrefixWithString: url options: NSLiteralSearch];
					if( [commonPath isEqualToString: [cB fixedDocumentsDirectory]])
						[self setPrimitiveValue: url forKey: @"reportURL"];
				}
			}
		}
	}
	#endif
	
	return url;
}

- (NSString *) localstring
{
	[[self managedObjectContext] lock];
	
	BOOL local = YES;
	
	@try 
	{
		NSManagedObject	*obj = [[[[self valueForKey:@"series"] anyObject] valueForKey:@"images"] anyObject];
	
		local = [[obj valueForKey:@"inDatabaseFolder"] boolValue];
	
		[[self managedObjectContext] unlock];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	if( local) return @"L";
	else return @"";
}

- (void) setDate:(NSDate*) date
{
	[dicomTime release];
	dicomTime = nil;
	
	[self willChangeValueForKey: @"date"];
	[self setPrimitiveValue: date forKey:@"date"];
	[self didChangeValueForKey: @"date"];
}

- (NSNumber*) dicomTime
{
	if( dicomTime) return dicomTime;
	
	dicomTime = [[[DCMCalendarDate dicomTimeWithDate:[self valueForKey: @"date"]] timeAsNumber] retain];
	
	return dicomTime;
}


//ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ

- (NSString*) yearOldAcquisition
{
	if( [self valueForKey: @"dateOfBirth"])
	{
		NSCalendarDate *momsBDay = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"dateOfBirth"] timeIntervalSinceReferenceDate]];
		NSCalendarDate *dateOfBirth = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"date"] timeIntervalSinceReferenceDate]];
		
		NSInteger years, months, days;
		
		[dateOfBirth years:&years months:&months days:&days hours:NULL minutes:NULL seconds:NULL sinceDate:momsBDay];
		
		if( years < 2)
		{
			if( years < 1)
			{
				if( months < 1) return [NSString stringWithFormat: NSLocalizedString( @"%d d", @"d = day"), days];
				else return [NSString stringWithFormat: NSLocalizedString( @"%d m", @"m = month"), months];
			}
			else return [NSString stringWithFormat: NSLocalizedString( @"%d y %d m", @"y = year, m = month") ,years, months];
		}
		else return [NSString stringWithFormat: NSLocalizedString( @"%d y", @"y = year"), years];
	}
	else return @"";
}

- (NSString*) yearOld
{
	if( [self valueForKey: @"dateOfBirth"])
	{
		NSCalendarDate *momsBDay = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: [[self valueForKey:@"dateOfBirth"] timeIntervalSinceReferenceDate]];
		NSCalendarDate *dateOfBirth = [NSCalendarDate date];
		
		NSInteger years, months, days;
		
		[dateOfBirth years:&years months:&months days:&days hours:NULL minutes:NULL seconds:NULL sinceDate:momsBDay];
		
		if( years < 2)
		{
			if( years < 1)
			{
				if( months < 1) return [NSString stringWithFormat: NSLocalizedString( @"%d d", @"d = day"), days];
				else return [NSString stringWithFormat: NSLocalizedString( @"%d m", @"m = month"), months];
			}
			else return [NSString stringWithFormat: NSLocalizedString( @"%d y %d m", @"y = year, m = month"),years, months];
		}
		else return [NSString stringWithFormat: NSLocalizedString( @"%d y", @"y = year"), years];
	}
	else return @"";
}


//ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ

- (NSNumber *) rawNoFiles
{
	int sum = 0;
	
	[[self managedObjectContext] lock];
	
	@try 
	{
		for( DicomSeries *s in [[self valueForKey:@"series"] allObjects])
			sum += [[s valueForKey: @"rawNoFiles"] intValue];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return [NSNumber numberWithInt:sum];
}

- (NSNumber *) noFilesExcludingMultiFrames
{
	if( [[self primitiveValueForKey:@"numberOfImages"] intValue] <= 0) // There are frames !
	{
		[[self managedObjectContext] lock];
		
		int sum = 0;
		
		@try 
		{
			for( DicomSeries *s in [[self valueForKey:@"series"] allObjects])
			{
				sum += [[s valueForKey:@"noFilesExcludingMultiFrames"] intValue];
			}
		}
		@catch (NSException * e) 
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
		
		[[self managedObjectContext] unlock];
		
		return [NSNumber numberWithInt:sum];
	}
	else return [self noFiles];
}

- (NSNumber *) noFiles
{
	int n = [[self primitiveValueForKey:@"numberOfImages"] intValue];
	if( n == 0)
	{
		[[self managedObjectContext] lock];
		
		int sum = 0;
		NSNumber *no = nil;
		
		@try 
		{
			BOOL framesInSeries = NO;
			
			for( DicomSeries *s in [[self valueForKey:@"series"] allObjects])
			{
				if( [DCMAbstractSyntaxUID isStructuredReport: [s valueForKey: @"seriesSOPClassUID"]] == NO &&
					[DCMAbstractSyntaxUID isSupportedPrivateClasses: [s valueForKey: @"seriesSOPClassUID"]] == NO &&
					[DCMAbstractSyntaxUID isPresentationState: [s valueForKey: @"seriesSOPClassUID"]] == NO)
				{
					sum += [[s valueForKey:@"noFiles"] intValue];
					
					if( [[s primitiveValueForKey:@"numberOfImages"] intValue] < 0) // There are frames !
						framesInSeries = YES;
				}
			}
			
			if( framesInSeries)
				sum = -sum;
			
			no = [NSNumber numberWithInt: sum];
			
			[self willChangeValueForKey: @"numberOfImages"];
			[self setPrimitiveValue: no forKey:@"numberOfImages"];
			[self didChangeValueForKey: @"numberOfImages"];
		}
		@catch (NSException * e) 
		{
			NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
		}
		
		[[self managedObjectContext] unlock];
		
		if( sum < 0)
			return [NSNumber numberWithInt: -sum];
		else
			return no;
	}
	else
	{
		if( n < 0)
			return [NSNumber numberWithInt: -n];
		else
			return [self primitiveValueForKey:@"numberOfImages"];
	}
}

//ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ

- (NSSet*) paths
{
	[[self managedObjectContext] lock];
	
	NSMutableSet *set = [NSMutableSet set];
	
	@try 
	{
		NSSet *sets = [self valueForKeyPath: @"series.images.completePath"];
	
		for (id subset in sets)
			[set unionSet: subset];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return set;
}


//ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ

- (NSSet*) keyImages
{
	[[self managedObjectContext] lock];
	
	NSMutableSet *set = [NSMutableSet set];
	
	@try 
	{
		NSEnumerator *enumerator = [[self primitiveValueForKey: @"series"] objectEnumerator];
	
		id object;
		while (object = [enumerator nextObject])
			[set unionSet:[object keyImages]];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
		
	[[self managedObjectContext] unlock];
	
	return set;
}

//ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ------------------------ Series subselections-----------------------------------ΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡΡ

+ (BOOL) displaySeriesWithSOPClassUID: (NSString*) uid andSeriesDescription: (NSString*) description
{
	if( uid == nil || [DCMAbstractSyntaxUID isImageStorage: uid] || [DCMAbstractSyntaxUID isRadiotherapy:uid])
		return YES;
	else if( [DCMAbstractSyntaxUID isStructuredReport:uid])		//&& [description isEqualToString: @"OsiriX ROI SR"] == NO && [description isEqualToString: @"OsiriX Annotations SR"] == NO && [description isEqualToString: @"OsiriX Report SR"] == NO)
		return YES;
	else
		return NO;
}

- (NSArray *)imageSeries
{
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try
	{
		for (id series in [self primitiveValueForKey: @"series"])
		{
			if( [DicomStudy displaySeriesWithSOPClassUID: [series valueForKey:@"seriesSOPClassUID"] andSeriesDescription: [series valueForKey: @"name"]])
				[newArray addObject:series];
		}
	}
	@catch (NSException *e)
	{
		NSLog( @"imageSeries exception: %@", e);
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)keyObjectSeries
{
	[[self managedObjectContext] lock];
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try 
	{
		NSArray *array = [self primitiveValueForKey: @"series"];
		
		for (id series in array)
		{
			if ([[DCMAbstractSyntaxUID keyObjectSelectionDocumentStorage] isEqualToString:[series valueForKey:@"seriesSOPClassUID"]])
				[newArray addObject:series];
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)keyObjects
{
	[[self managedObjectContext] lock];
	
	NSMutableSet *set = [NSMutableSet set];
	
	@try 
	{
		NSArray *array = [self keyObjectSeries];
	
		for (id series in array)
			[set unionSet:[series primitiveValueForKey:@"images"]];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return [set allObjects];
}

- (NSArray *)presentationStateSeries
{
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try 
	{
		NSArray *array = [self primitiveValueForKey: @"series"];
	
		for (id series in array)
		{
			if ([DCMAbstractSyntaxUID isPresentationState:[series valueForKey:@"seriesSOPClassUID"]])
				[newArray addObject:series];
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSArray *)waveFormSeries
{
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try 
	{
		NSArray *array = [self primitiveValueForKey: @"series"];
	
		for (id series in array)
		{
			if ([DCMAbstractSyntaxUID isWaveform:[series valueForKey:@"seriesSOPClassUID"]])
				[newArray addObject:series];
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return newArray;
}

- (NSManagedObject *) annotationsSRImage // Comments, Status, Key Images, ...
{
	NSArray *array = [self primitiveValueForKey: @"series"];
	if ([array count] < 1)  return nil;
	
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	NSManagedObject *image = nil;
	
	@try 
	{
		for( DicomSeries *series in array)
		{
			if( [[series valueForKey:@"id"] intValue] == 5004 && [[series valueForKey:@"name"] isEqualToString: @"OsiriX Annotations SR"] == YES && [DCMAbstractSyntaxUID isStructuredReport:[series valueForKey:@"seriesSOPClassUID"]] == YES)
				[newArray addObject: series];
		}
		
		// Take the most recent series
		if( [newArray count] > 1)
		{
			NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: YES] autorelease];
			newArray = [[[newArray sortedArrayUsingDescriptors: [NSArray arrayWithObject: sort]] mutableCopy] autorelease];
		}
		
		if( [[[newArray lastObject] valueForKey: @"images"] count] > 1)
		{
			NSArray *images = [[[newArray lastObject] valueForKey: @"images"] allObjects];
			
			// Take the most recent image
			NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: YES] autorelease];
			images = [images sortedArrayUsingDescriptors: [NSArray arrayWithObject: sort]];
			
			image = [images lastObject];
		}
		else image = [[[newArray lastObject] valueForKey: @"images"] anyObject];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return image;
}

- (NSManagedObject *) reportSRSeries
{
	NSArray *array = [self primitiveValueForKey: @"series"] ;
	if ([array count] < 1)  return nil;
	
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try 
	{
		for( DicomSeries *series in array)
		{
			if( [[series valueForKey:@"id"] intValue] == 5003 && [[series valueForKey:@"name"] isEqualToString: @"OsiriX Report SR"] == YES && [DCMAbstractSyntaxUID isStructuredReport:[series valueForKey:@"seriesSOPClassUID"]] == YES)
				[newArray addObject:series];
		}
		
		if( [newArray count] > 1)
		{
			NSLog( @"****** multiple (%d) reportSRSeries?? Delete the extra series...", [newArray count]);
			
			for( int i = 0 ; i < [newArray count]-1 ; i++)
				[[self managedObjectContext] deleteObject: [newArray objectAtIndex: i]]; 
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	if( [newArray count])
		return [newArray objectAtIndex: 0];
	
	return nil;
}

- (NSManagedObject *)roiSRSeries
{
	NSArray *array = [self primitiveValueForKey: @"series"] ;
	if ([array count] < 1)  return nil;
	
	[[self managedObjectContext] lock];
	
	NSMutableArray *newArray = [NSMutableArray array];
	
	@try 
	{
		for( DicomSeries *series in array)
		{
			if( [[series valueForKey:@"id"] intValue] == 5002 && [[series valueForKey:@"name"] isEqualToString: @"OsiriX ROI SR"] == YES && [DCMAbstractSyntaxUID isStructuredReport:[series valueForKey:@"seriesSOPClassUID"]] == YES)
				[newArray addObject:series];
		}
		
		if( [newArray count] > 1)
		{
			NSLog( @"****** multiple (%d) roiSRSeries?? Delete the extra series...", [newArray count]);
			
			for( int i = 0 ; i < [newArray count]-1 ; i++)
				[[self managedObjectContext] deleteObject: [newArray objectAtIndex: i]]; 
		}
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	if( [newArray count]) return [newArray objectAtIndex: 0];
	
	return nil;
}

- (NSDictionary *)dictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	if ([self primitiveValueForKey:@"name"])
		[dict  setObject: [self primitiveValueForKey:@"name"] forKey: @"Patients Name"];
	if ([self primitiveValueForKey:@"patientID"])
		[dict  setObject: [self primitiveValueForKey:@"patientID"] forKey: @"Patient ID"];
	if ([self primitiveValueForKey:@"studyName"])
		[dict  setObject: [self primitiveValueForKey:@"studyName"] forKey: @"Study Description"];
	if ([self primitiveValueForKey:@"patientSex"] )
		[dict  setObject: [self primitiveValueForKey:@"patientSex"] forKey: @"Patients Sex"];
	if ([self primitiveValueForKey:@"dateOfBirth"] )
		[dict  setObject: [self primitiveValueForKey:@"dateOfBirth"] forKey: @"Patients DOB"];
	if ([self primitiveValueForKey:@"institutionName"])
		[dict  setObject: [self primitiveValueForKey:@"institutionName"] forKey: @"Institution"];
	if ([self primitiveValueForKey:@"accessionNumber"])
		[dict  setObject: [self primitiveValueForKey:@"accessionNumber"] forKey: @"Accession Number"];
	if ([self primitiveValueForKey:@"comment"])
		[dict  setObject: [self primitiveValueForKey:@"comment"] forKey: @"Comment"];
	if ([self primitiveValueForKey:@"modality"])
		[dict  setObject: [self primitiveValueForKey:@"modality"] forKey: @"Modality"];
	if ([self primitiveValueForKey:@"date"])
		[dict  setObject: [self primitiveValueForKey:@"date"] forKey: @"Study Date"];
	if ([self primitiveValueForKey:@"performingPhysician"] )
		[dict  setObject: [self primitiveValueForKey:@"performingPhysician"] forKey: @"Performing Physician"];
	if ([self primitiveValueForKey:@"referringPhysician"])
		[dict  setObject: [self primitiveValueForKey:@"referringPhysician"] forKey: @"Referring Physician"];
	if ([self primitiveValueForKey:@"id"])
		[dict  setObject: [self primitiveValueForKey:@"id"] forKey: @"Study ID"];
	if ([self primitiveValueForKey:@"studyInstanceUID"])
		[dict  setObject: [self primitiveValueForKey:@"studyInstanceUID"] forKey: @"Study Instance UID"];

	return dict;
}

- (NSComparisonResult)compareName:(DicomStudy*)study;
{
	return [[self valueForKey:@"name"] caseInsensitiveCompare:[study valueForKey:@"name"]];
}

- (NSString*) albumsNames
{
	[[self managedObjectContext] lock];
	
	NSString *s = nil;
	@try 
	{
		s = [[[[self valueForKey: @"albums"] allObjects] valueForKey:@"name"] componentsJoinedByString:@"/"];
	}
	@catch (NSException * e) 
	{
		NSLog( @"***** exception in %s: %@", __PRETTY_FUNCTION__, e);
	}
	
	[[self managedObjectContext] unlock];
	
	return s;
}


//- (BOOL) validateForDelete:(NSError **)error
//{
//	BOOL delete = [super validateForDelete:(NSError **)error];
//	if( delete)
//	{
//		if( [self valueForKey:@"reportURL"])
//			[[NSFileManager defaultManager] removeFileAtPath: [self valueForKey:@"reportURL"] handler:nil];
//	}
//	return delete;
//}

@end
