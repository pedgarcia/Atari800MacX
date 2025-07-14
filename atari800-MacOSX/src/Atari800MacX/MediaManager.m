/* MediaManager.m - Window and menu support
   class to handle disk, cartridge, cassette,
   and executable file management and support 
   functions for the Macintosh OS X SDL port 
   of Atari800
   Mark Grebe <atarimacosx@gmail.com>
   
   Based on the Preferences pane of the
   TextEdit application.

*/
#import <Cocoa/Cocoa.h>
#import "afile.h"
#import "atari.h"
#import "atrUtil.h"
#import "atrMount.h"
#import "MediaManager.h"
#import "ControlManager.h"
#import "Preferences.h"
#import "DiskEditorWindow.h"
#import "DiskEditorDataSource.h"
#import "DisplayManager.h"
#import "PrintOutputController.h"
#import "SectorEditorWindow.h"
#import "KeyMapper.h"
#import "binload.h"
#import "cartridge.h"
#import "cassette.h"
#import "compfile.h"
#import "screen.h"
#import "sio.h"
#import "memory.h"
#import "stdio.h"
#import "SDL.h"
#import "esc.h"
#import "ui.h"
#import "img_raw.h"
#import "img_vhd.h"
#import "side2.h"
#import "ultimate1mb.h"
#import <sys/stat.h>
#import <unistd.h>

/* Definition of Mac native keycodes for characters used as menu shortcuts the 
	bring up a window. */
#define QZ_c			0x08
#define QZ_d			0x02
#define QZ_e			0x0E
#define QZ_o			0x1F
#define QZ_r			0x0F
#define QZ_1			0x12
#define QZ_n			0x2D

/* ATR Disk header */
typedef struct {
    UBYTE id[4];
    UBYTE type[4];
    UBYTE checksum[4];
    UBYTE gash[4];
} Header;

extern void PauseAudio(int pause);
extern int CalcAtariType(int machineType, int ramSize, int axlon, int mosaic, int ultimate, int basic, int game, int leds, int jumper);
extern int Atari800_jumper_present;
extern char atari_disk_dirs[][FILENAME_MAX];
extern char atari_diskset_dir[FILENAME_MAX];
extern char atari_rom_dir[FILENAME_MAX];
extern char atari_exe_dir[FILENAME_MAX];
extern char atari_cass_dir[FILENAME_MAX];
extern int cart_type;
extern int requestCaptionChange;
extern int requestArtifChange;
extern int request80ColChange;
extern int dcmtoatr(FILE *fin, FILE *fout, const char *input, char *output );
extern int mediaStatusWindowOpen;
extern int currPrinter;
extern int Devices_enable_d_patch;
extern int Devices_enable_p_patch;
extern void CalcMachineTypeRam(int type, int *machineType, int *ramSize,
                        int *axlon, int *mosaic, int *ultimate,
                        int *basic, int *game, int *leds, int *jumper);
extern int machine_switch_type;
extern void Atari_DisplayScreen(UBYTE * screen);
extern int requestMachineTypeChange;
extern int requestScaleModeChange;
extern int requestWidthModeChange;
extern int ANTIC_artif_mode;
extern int WIDTH_MODE;
extern int scaleFactor;
extern int SCALE_MODE;
extern int Atari800_machine_type;
extern int MEMORY_ram_size;
extern int diskDriveSound;
extern int PREFS_axlon_num_banks;
extern int PREFS_mosaic_num_banks;
extern int XEP80_port;
extern int ULTIMATE_enabled;
extern int SIDE2_enabled;

/* Arrays which define the cartridge types for each size */
static int CART2KTYPES[] = {CARTRIDGE_STD_2};
static int CART4KTYPES[] = {CARTRIDGE_BLIZZARD_4, CARTRIDGE_STD_4, CARTRIDGE_RIGHT_4};
static int CART8KTYPES[] = {CARTRIDGE_STD_8, CARTRIDGE_5200_8, CARTRIDGE_RIGHT_8,
                            CARTRIDGE_PHOENIX_8, CARTRIDGE_OSS_8, CARTRIDGE_LOW_BANK_8};
static int CART16KTYPES[] = {CARTRIDGE_STD_16, CARTRIDGE_OSS_034M_16, CARTRIDGE_5200_EE_16,
                             CARTRIDGE_OSS_M091_16, CARTRIDGE_5200_NS_16, CARTRIDGE_MEGA_16,
                             CARTRIDGE_BLIZZARD_16, CARTRIDGE_OSS_043M_16};
static int CART32KTYPES[] = {CARTRIDGE_5200_32, CARTRIDGE_DB_32, CARTRIDGE_XEGS_32, 
                             CARTRIDGE_WILL_32, CARTRIDGE_MEGA_32, CARTRIDGE_SWXEGS_32,
                             CARTRIDGE_AST_32, CARTRIDGE_ULTRACART_32, CARTRIDGE_BLIZZARD_32,
                             CARTRIDGE_ADAWLIAH_32};
static int CART40KTYPES[] = {CARTRIDGE_5200_40, CARTRIDGE_BBSB_40};
static int CART64KTYPES[] = {CARTRIDGE_WILL_64, CARTRIDGE_EXP_64, CARTRIDGE_DIAMOND_64,
                             CARTRIDGE_SDX_64, CARTRIDGE_XEGS_07_64, CARTRIDGE_MEGA_64,
                             CARTRIDGE_SWXEGS_64, CARTRIDGE_ATRAX_SDX_64,
                             CARTRIDGE_TURBOSOFT_64, CARTRIDGE_XEGS_8F_64,
                             CARTRIDGE_ADAWLIAH_64};
static int CART128KTYPES[] = {CARTRIDGE_XEGS_128, CARTRIDGE_ATRAX_128, CARTRIDGE_MEGA_128,
                              CARTRIDGE_SWXEGS_128, CARTRIDGE_ATMAX_128, CARTRIDGE_SDX_128,
                              CARTRIDGE_ATRAX_SDX_128, CARTRIDGE_TURBOSOFT_128, CARTRIDGE_SIC_128,
                              CARTRIDGE_ATRAX_128};
static int CART256KTYPES[] = {CARTRIDGE_XEGS_256, CARTRIDGE_MEGA_256, CARTRIDGE_SWXEGS_256,
                              CARTRIDGE_SIC_256};
static int CART512KTYPES[] = {CARTRIDGE_XEGS_512, CARTRIDGE_MEGA_512, CARTRIDGE_SWXEGS_512,
                              CARTRIDGE_SIC_512};
static int CART1024KTYPES[] = {CARTRIDGE_XEGS_1024, CARTRIDGE_MEGA_1024, CARTRIDGE_SWXEGS_1024,
                               CARTRIDGE_ATMAX_1024};
static int CART2048KTYPES[] = {CARTRIDGE_MEGAMAX_2048, CARTRIDGE_MEGA_2048};
static int CART4096KTYPES[] = {CARTRIDGE_MEGA_4096};
static int CART32MTYPES[] = {CARTRIDGE_THECART_32M};
static int CART64MTYPES[] = {CARTRIDGE_THECART_64M};
static int CART128MTYPES[] = {CARTRIDGE_THECART_128M};

int showUpperDrives = 0;

/* Functions which provide an interface for C code to call this object's shared Instance functions */
void UpdateMediaManagerInfo() {
    [[MediaManager sharedInstance] updateInfo];
}

void MediaManagerRunDiskManagement() {
    [[MediaManager sharedInstance] showManagementPanel:nil];
}

void MediaManagerShowCreatePanel(void) {
    [[MediaManager sharedInstance] showCreatePanel:nil];
}

void MediaManagerRunDiskEditor() {
    [[MediaManager sharedInstance] showEditorPanel:nil];
}

void MediaManagerRunSectorEditor() {
    [[MediaManager sharedInstance] showSectorPanel:nil];
}

void MediaManagerInsertCartridge() {
    [[MediaManager sharedInstance] cartInsert:nil];
}

void MediaManagerRemoveCartridge() {
    [[MediaManager sharedInstance] cartRemove:nil];
}

void MediaManagerInsertDisk(int diskNum) {
    [[MediaManager sharedInstance] diskInsertKey:diskNum];
}

void MediaManagerRemoveDisk(int diskNum) {
    if (diskNum == 0)
        [[MediaManager sharedInstance] diskRemoveAll:nil];
    else
        [[MediaManager sharedInstance] diskRemoveKey:diskNum];
}

void MediaManagerLoadExe() {
    [[MediaManager sharedInstance] loadExeFile:nil];
}

void MediaManagerStatusLed(int diskNo, int on, int read) {
    if (diskNo >= 0 && diskNo < 8)
		if (SIO_drive_status[diskNo] == SIO_READ_WRITE || SIO_drive_status[diskNo] == SIO_READ_ONLY)
			[[MediaManager sharedInstance] statusLed:diskNo:on:read];
}

void MediaManagerSectorLed(int diskNo, int sectorNo, int on) {
    if (diskNo >= 0 && diskNo < 8)
		if (SIO_drive_status[diskNo] == SIO_READ_WRITE || SIO_drive_status[diskNo] == SIO_READ_ONLY)
			[[MediaManager sharedInstance] sectorLed:diskNo:sectorNo:on];
}

void MediaManagerCassSliderUpdate(int block) {
	[[MediaManager sharedInstance] cassSliderUpdate:block];
}

void MediaManagerStatusWindowShow(void) {
 [[MediaManager sharedInstance] mediaStatusWindowShow:nil];
}

void MediaManager80ColMode(int xep80Enabled, int af80Enabled, int bit3Enabled, int col80) {
    [[MediaManager sharedInstance] set80ColMode:(xep80Enabled):(af80Enabled):(bit3Enabled):(col80)];
    }

int MediaManagerCartSelect(int nKbytes) {
    return([[MediaManager sharedInstance] cartSelect:(nKbytes)]);
}

@implementation MediaManager

static MediaManager *sharedInstance = nil;

static NSImage *off810Image;
static NSImage *empty810Image;
static NSImage *closed810Image;
static NSImage *read810Image;
static NSImage *write810Image;
static NSImage *on410Image;
static NSImage *off410Image;
static NSImage *onCartImage;
static NSImage *offCartImage;
static NSImage *lockImage;
static NSImage *lockoffImage;
static NSImage *atari825Image;
static NSImage *atari1020Image;
static NSImage *epsonImage;
static NSImage *textImage;
static NSImage *atasciiImage;
NSImage *disketteImage;

+ (MediaManager *)sharedInstance {
    return sharedInstance ? sharedInstance : [[self alloc] init];
}

- (id)init {
    NSArray *top;
    if (sharedInstance) {
	[self dealloc];
    } else {
        [super init];
		[Preferences sharedInstance];
        sharedInstance = self;
        /* load the nib and all the windows */
        if (!d1DiskField) {
				if (![[NSBundle mainBundle] loadNibNamed:@"MediaManager" owner:self topLevelObjects:&top])  {
					NSLog(@"Failed to load MediaManager.nib");
					NSBeep();
					return nil;
 			}
            [top retain];
            }
    [[diskFmtMatrix window] setExcludedFromWindowsMenu:YES];
    [[diskFmtMatrix window] setMenu:nil];
    [[hardDiskFmtMatrix window] setExcludedFromWindowsMenu:YES];
    [[hardDiskFmtMatrix window] setMenu:nil];
	[[d1DiskField window] setExcludedFromWindowsMenu:YES];
	[[d1DiskField window] setMenu:nil];
	[[errorButton window] setExcludedFromWindowsMenu:YES];
	[[errorButton window] setMenu:nil];
    [[cart2KMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart2KMatrix window] setMenu:nil];
    [[cart4KMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart4KMatrix window] setMenu:nil];
    [[cart8KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart8KMatrix window] setMenu:nil];
	[[cart16KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart16KMatrix window] setMenu:nil];
	[[cart32KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart32KMatrix window] setMenu:nil];
	[[cart40KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart40KMatrix window] setMenu:nil];
	[[cart64KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart64KMatrix window] setMenu:nil];
	[[cart128KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart128KMatrix window] setMenu:nil];
	[[cart256KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart256KMatrix window] setMenu:nil];
	[[cart512KMatrix window] setExcludedFromWindowsMenu:YES];
	[[cart512KMatrix window] setMenu:nil];
    [[cart1024KMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart1024KMatrix window] setMenu:nil];
    [[cart2048KMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart2048KMatrix window] setMenu:nil];
    [[cart4096KMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart4096KMatrix window] setMenu:nil];
    [[cart32MMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart32MMatrix window] setMenu:nil];
    [[cart64MMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart64MMatrix window] setMenu:nil];
    [[cart128MMatrix window] setExcludedFromWindowsMenu:YES];
    [[cart128MMatrix window] setMenu:nil];
	[[d1DiskImageView window] setExcludedFromWindowsMenu:NO];
	
    off810Image = [NSImage imageNamed:@"atari810off"];
    empty810Image = [NSImage imageNamed:@"atari810emtpy"];
    closed810Image = [NSImage imageNamed:@"atari810closed"];
    read810Image = [NSImage imageNamed:@"atari810read"];
    write810Image = [NSImage imageNamed:@"atari810write"];
    on410Image = [NSImage imageNamed:@"cassetteon"];
    off410Image = [NSImage imageNamed:@"cassetteoff"];
	onCartImage = [NSImage imageNamed:@"cartridgeon"];
    offCartImage = [NSImage imageNamed:@"cartridgeoff"];
    lockImage = [NSImage imageNamed:@"lock"];
	
	lockoffImage = [NSImage alloc];
    [lockoffImage initWithSize: NSMakeSize(11.0,14.0)];
    [lockoffImage setBackgroundColor:[NSColor textBackgroundColor]];

    epsonImage = [NSImage imageNamed:@"epson"];
    atari825Image = [NSImage imageNamed:@"atari825"];		
    atari1020Image = [NSImage imageNamed:@"atari1020"];
    textImage = [NSImage imageNamed:@"text"];
    atasciiImage = [NSImage imageNamed:@"atascii"];
    disketteImage = [NSImage imageNamed:@"diskette"];
	}
	
    return sharedInstance;
}

- (void)dealloc {
	[super dealloc];
}

/*------------------------------------------------------------------------------
*  mediaStatusWindowShow - This method makes the media status window visable
*-----------------------------------------------------------------------------*/
- (void)mediaStatusWindowShow:(id)sender
{
	static int firstTime = 1;

	if (firstTime) {
		[[d1DiskImageView window] setFrameOrigin:[[Preferences sharedInstance] mediaStatusOrigin]];
		firstTime = 0;
		}
	
    [[d1DiskImageView window] makeKeyAndOrderFront:self];
	[[d1DiskImageView window] setTitle:@"Atari Media"];
	mediaStatusWindowOpen = TRUE;
}

/*------------------------------------------------------------------------------
*  mediaStatusOriginSave - This method saves the position of the media status
*    window
*-----------------------------------------------------------------------------*/
- (NSPoint)mediaStatusOriginSave
{
	NSRect frame;
	
	frame = [[d1DiskImageView window] frame];
	return(frame.origin);
}

/*------------------------------------------------------------------------------
*  displayError - This method displays an error dialog box with the passed in
*     error message.
*-----------------------------------------------------------------------------*/
- (void)displayError:(NSString *)errorMsg {
    [errorField setStringValue:errorMsg];
    [NSApp runModalForWindow:[errorButton window]];
}

/*------------------------------------------------------------------------------
*  displayError2 - This method displays an error dialog box with the passed in
*     error messages.
*-----------------------------------------------------------------------------*/
- (void)displayError2:(NSString *)errorMsg1:(NSString *)errorMsg2 {
    [error2Field1 setStringValue:errorMsg1];
    [error2Field2 setStringValue:errorMsg2];
    [NSApp runModalForWindow:[error2Button window]];
}

/*------------------------------------------------------------------------------
*  updateInfo - This method is used to update the disk management window GUI.
*-----------------------------------------------------------------------------*/
- (void)updateInfo {
    int i;
    int noDisks = TRUE;
	int type, ver4type, ver5type, index;
	
    for (i=0;i<8;i++) {
        if (SIO_drive_status[i] == SIO_OFF)
            strcpy(SIO_filename[i],"Off");
        switch(i) {
            case 0:
                [d1DiskField setStringValue:[NSString stringWithCString:SIO_filename[0] encoding:NSUTF8StringEncoding]];
                [d1DriveStatusPulldown selectItemAtIndex:SIO_drive_status[0]];
                if (SIO_drive_status[0] == SIO_OFF || SIO_drive_status[0] == SIO_NO_DISK)
                    [removeD1Item setTarget:nil];
                else {
                    [removeD1Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 1:
                [d2DiskField setStringValue:[NSString stringWithCString:SIO_filename[1] encoding:NSUTF8StringEncoding]];
                [d2DriveStatusPulldown selectItemAtIndex:SIO_drive_status[1]];
                if (SIO_drive_status[1] == SIO_OFF || SIO_drive_status[1] == SIO_NO_DISK)
                    [removeD2Item setTarget:nil];
                else {
                    [removeD2Item setTarget:self];
                    noDisks = FALSE;
                    }
            case 2:
                [d3DiskField setStringValue:[NSString stringWithCString:SIO_filename[2] encoding:NSUTF8StringEncoding]];
                [d3DriveStatusPulldown selectItemAtIndex:SIO_drive_status[2]];
                if (SIO_drive_status[2] == SIO_OFF || SIO_drive_status[2] == SIO_NO_DISK)
                    [removeD3Item setTarget:nil];
                else {
                    [removeD3Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 3:
                [d4DiskField setStringValue:[NSString stringWithCString:SIO_filename[3] encoding:NSUTF8StringEncoding]];
                [d4DriveStatusPulldown selectItemAtIndex:SIO_drive_status[3]];
                if (SIO_drive_status[3] == SIO_OFF || SIO_drive_status[3] == SIO_NO_DISK)
                    [removeD4Item setTarget:nil];
                else {
                    [removeD4Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 4:
                [d5DiskField setStringValue:[NSString stringWithCString:SIO_filename[4] encoding:NSUTF8StringEncoding]];
                [d5DriveStatusPulldown selectItemAtIndex:SIO_drive_status[4]];
                if (SIO_drive_status[4] == SIO_OFF || SIO_drive_status[4] == SIO_NO_DISK)
                    [removeD5Item setTarget:nil];
                else {
                    [removeD5Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 5:
                [d6DiskField setStringValue:[NSString stringWithCString:SIO_filename[5] encoding:NSUTF8StringEncoding]];
                [d6DriveStatusPulldown selectItemAtIndex:SIO_drive_status[5]];
                if (SIO_drive_status[5] == SIO_OFF || SIO_drive_status[5] == SIO_NO_DISK)
                    [removeD6Item setTarget:nil];
                else {
                    [removeD6Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 6:
                [d7DiskField setStringValue:[NSString stringWithCString:SIO_filename[6] encoding:NSUTF8StringEncoding]];
                [d7DriveStatusPulldown selectItemAtIndex:SIO_drive_status[6]];
                if (SIO_drive_status[6] == SIO_OFF || SIO_drive_status[6] == SIO_NO_DISK)
                    [removeD7Item setTarget:nil];
                else {
                    [removeD7Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            case 7:
                [d8DiskField setStringValue:[NSString stringWithCString:SIO_filename[7] encoding:NSUTF8StringEncoding]];
                [d8DriveStatusPulldown selectItemAtIndex:SIO_drive_status[7]];
                if (SIO_drive_status[7] == SIO_OFF || SIO_drive_status[7] == SIO_NO_DISK)
                    [removeD8Item setTarget:nil];
                else {
                    [removeD8Item setTarget:self];
                    noDisks = FALSE;
                    }
                break;
            }
        }
        if (noDisks) 
            [removeMenu setTarget:nil];
        else 
            [removeMenu setTarget:self];
    if (ULTIMATE_enabled) {
        if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE)
                [removeCartItem setTarget:nil];
            else
                [removeCartItem setTarget:self];
    } else {
        if (CARTRIDGE_main.type == CARTRIDGE_NONE)
                [removeCartItem setTarget:nil];
            else
                [removeCartItem setTarget:self];
    }
    if (CARTRIDGE_main.type == CARTRIDGE_SDX_64 || CARTRIDGE_main.type == CARTRIDGE_SDX_128 ||
        CARTRIDGE_main.type == CARTRIDGE_ATRAX_SDX_64 || CARTRIDGE_main.type == CARTRIDGE_ATRAX_SDX_128)
        [insertSecondCartItem setTarget:self];
    else
        [insertSecondCartItem setTarget:nil];
    if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE)
        [removeSecondCartItem setTarget:nil];
    else
        [removeSecondCartItem setTarget:self];
    if (ULTIMATE_enabled) {
        [saveUltimateRomItem setTarget:self];
        [changeUltimateRomItem setTarget:self];
    } else {
        [saveUltimateRomItem setTarget:nil];
        [saveUltimateRomItem setTarget:nil];
    }
    if (SIDE2_enabled) {
        [saveSIDE2RomItem setTarget:self];
        [changeSIDE2RomItem setTarget:self];
        if (SIDE2_Block_Device) {
            [attachSIDE2CFItem setTarget:self];
            [removeSIDE2CFItem setTarget:self];
        } else {
            [attachSIDE2CFItem setTarget:self];
            [removeSIDE2CFItem setTarget:nil];
        }
        [slideSIDE2ButtonSDXItem setTarget:self];
        [slideSIDE2ButtonLoaderItem setTarget:self];
        [pressSIDE2ButtonItem setTarget:self];
    } else {
        [saveSIDE2RomItem setTarget:nil];
        [changeSIDE2RomItem setTarget:nil];
        [attachSIDE2CFItem setTarget:nil];
        [removeSIDE2CFItem setTarget:nil];
        [slideSIDE2ButtonSDXItem setTarget:nil];
        [slideSIDE2ButtonLoaderItem setTarget:nil];
        [pressSIDE2ButtonItem setTarget:nil];
    }
    if (SIDE2_SDX_Mode_Switch) {
        [slideSIDE2ButtonSDXItem setState:NSOnState];
        [slideSIDE2ButtonLoaderItem setState:NSOffState];
    } else {
        [slideSIDE2ButtonSDXItem setState:NSOffState];
        [slideSIDE2ButtonLoaderItem setState:NSOnState];
    }
    if (CASSETTE_status == CASSETTE_STATUS_NONE)
        {
        [protectCassItem setTarget:nil];
        [recordCassItem setTarget:nil];
        [recordCassItem setState:NSOffState];
        [removeCassItem setTarget:nil];
        [rewindCassItem setTarget:nil];
        }
    else {
        [protectCassItem setTarget:self];
        [recordCassItem setTarget:self];
        [removeCassItem setTarget:self];
        [rewindCassItem setTarget:self];
        if (CASSETTE_record)
            [recordCassItem setState:NSOnState];
        else
            [recordCassItem setState:NSOffState];
        if (CASSETTE_write_protect)
            [protectCassItem setState:NSOnState];
        else
            [protectCassItem setState:NSOffState];
        }
	
	type = CalcAtariType(Atari800_machine_type, MEMORY_ram_size,
						 MEMORY_axlon_num_banks > 0, MEMORY_mosaic_num_banks > 0, ULTIMATE_enabled,
                         Atari800_builtin_basic,
                         Atari800_builtin_game,
                         Atari800_keyboard_leds,
                         Atari800_jumper_present);
    if (type > 18) {
        ver5type = type - 19;
        ver4type = -1;
    } else {
        ver5type = -1;
        if (type > 13) {
            ver4type = type - 14;
            type = 0;
        } else {
            ver4type = -1;
        }
    }
    index = [[Preferences sharedInstance] indexFromType:type :ver4type :ver5type];
		
	[machineTypePulldown selectItemAtIndex:index];
    if (SCALE_MODE > 1)
        [scaleModePulldown selectItemAtIndex:0];
    else
        [scaleModePulldown selectItemAtIndex:SCALE_MODE];
	[widthModePulldown selectItemAtIndex:WIDTH_MODE];
	[artifactModePulldown selectItemAtIndex:ANTIC_artif_mode];
	[self updateMediaStatusWindow];
}

/*------------------------------------------------------------------------------
*  browseFileInDirectory - This allows the user to chose a file to read in from
*     the specified directory.
*-----------------------------------------------------------------------------*/
- (NSString *) browseFileInDirectory:(NSString *)directory {
    NSOpenPanel *openPanel = nil;
    
    openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:directory]];
    if ([openPanel runModal] == NSModalResponseOK)
        return([[[openPanel URLs] objectAtIndex:0] path]);
    else
        return nil;
    }

/*------------------------------------------------------------------------------
*  browseFileTypeInDirectory - This allows the user to chose a file of a 
*     specified typeto read in from the specified directory.
*-----------------------------------------------------------------------------*/
- (NSString *) browseFileTypeInDirectory:(NSString *)directory:(NSArray *) filetypes {
    NSOpenPanel *openPanel = nil;
	
    openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:filetypes];
    
    if ([openPanel runModal] == NSModalResponseOK)
        return([[[openPanel URLs] objectAtIndex:0] path]);
    else
        return nil;
    }

/*------------------------------------------------------------------------------
*  saveFileInDirectory - This allows the user to chose a filename to save in from
*     the specified directory.
*-----------------------------------------------------------------------------*/
- (NSString *) saveFileInDirectory:(NSString *)directory:(NSString *)type {
    NSSavePanel *savePanel = nil;
    
    savePanel = [NSSavePanel savePanel];
    
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:type]];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:directory]];

    if ([savePanel runModal] == NSModalResponseOK)
        return([[savePanel URL] path]);
    else
        return nil;
    }

/*------------------------------------------------------------------------------
*  cancelDisk - This method handles the cancel button from the disk image
*     creation window.
*-----------------------------------------------------------------------------*/
- (IBAction)cancelDisk:(id)sender
{
    [NSApp stopModal];
    [[diskFmtMatrix window] close];
}

/*------------------------------------------------------------------------------
*  cancelHardDisk - This method handles the cancel button from the disk image
*     creation window.
*-----------------------------------------------------------------------------*/
- (IBAction)cancelHardDisk:(id)sender
{
    [NSApp stopModal];
    [[hardDiskFmtMatrix window] close];
}

/*------------------------------------------------------------------------------
*  basicInsert - This method inserts the BASIC cartridge image into the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)basicInsert:(id)sender
{
    if (Atari800_machine_type != Atari800_MACHINE_5200) {
        /* BASIC cartridge support removed in newer core */
        memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
        Atari_DisplayScreen((UBYTE *) Screen_atari);
        Atari800_Coldstart();
        [self updateInfo];
        [[ControlManager sharedInstance] setDisableBasicMenu:Atari800_machine_type:Atari800_disable_basic];
        
    }
}

/*------------------------------------------------------------------------------
*  side2Insert - This method inserts the SIDE2 cartridge  into the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)side2Insert:(id)sender
{
    if (Atari800_machine_type == Atari800_MACHINE_XLXE) {
        /* SIDE2 cartridge support removed in newer core */
        memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
        Atari_DisplayScreen((UBYTE *) Screen_atari);
        Atari800_Coldstart();
        [self updateInfo];
    }
}

/*------------------------------------------------------------------------------
*  cartInsert - This method inserts a cartridge image into the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)cartInsert:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int cartSize;

    PauseAudio(1);
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        if (ULTIMATE_enabled) {
            cartSize = CARTRIDGE_Insert_Second(cfilename);
            if (cartSize > 0)
                CARTRIDGE_piggyback.type = [self cartSelect:cartSize];
        } else {
            cartSize = CARTRIDGE_Insert(cfilename);
            if (cartSize > 0)
                CARTRIDGE_main.type = [self cartSelect:cartSize];
        }

        memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
        Atari_DisplayScreen((UBYTE *) Screen_atari);
        Atari800_Coldstart();
        }
    [self updateInfo];
    [[KeyMapper sharedInstance] releaseCmdKeys:@"o"];
    PauseAudio(0);
}

/*------------------------------------------------------------------------------
*  cartSecondInsert - This method inserts a piggback cartridge image into 
*     a SpartaX cartridge in the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)cartSecondInsert:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int cartSize;

    PauseAudio(1);
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        cartSize = CARTRIDGE_Insert_Second(cfilename);
        if (cartSize > 0) 
            CARTRIDGE_piggyback.type = [self cartSelect:cartSize];
        }
    [self updateInfo];
    PauseAudio(0);
}

/*------------------------------------------------------------------------------
*  cartInsertFile - This method inserts a cartridge image into the emulator,
*     given it's filename.
*-----------------------------------------------------------------------------*/
- (void)cartInsertFile:(NSString *)filename
{
    char cfilename[FILENAME_MAX];
    int cartSize;

    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        cartSize = CARTRIDGE_Insert(cfilename);
        if (cartSize > 0)
            CARTRIDGE_main.type = [self cartSelect:cartSize];
		memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
		Atari_DisplayScreen((UBYTE *) Screen_atari);
        Atari800_Coldstart();
        }
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassRemove - This method removes a cartridge image from the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)cartRemove:(id)sender
{
    if (ULTIMATE_enabled)
        CARTRIDGE_Remove_Second();
    else
        CARTRIDGE_Remove();
    [self updateInfo];
    [[ControlManager sharedInstance] setDisableBasicMenu:Atari800_machine_type:Atari800_disable_basic];
    Atari800_Coldstart();
}

/*------------------------------------------------------------------------------
*  cartSecondRemove - This method removes a piggback cartridge image into 
*     a SpartaX cartridge in the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)cartSecondRemove:(id)sender
{
    CARTRIDGE_Remove_Second();
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassSelect - This method displays a dialog box so that the user can select
*     a cartridge type based on the passed in size in Kbytes.
*-----------------------------------------------------------------------------*/
- (int)cartSelect:(int)cartSize 
{
    int cartType;
    NSWindow *theWindow;

    switch (cartSize) {
        case 2:
            theWindow = [cart2KMatrix window];
            break;
        case 4:
            theWindow = [cart4KMatrix window];
            break;
        case 8:
            theWindow = [cart8KMatrix window];
            break;
        case 16:
            theWindow = [cart16KMatrix window];
            break;
        case 32:
            theWindow = [cart32KMatrix window];
            break;
        case 40:
            theWindow = [cart40KMatrix window];
            break;
        case 64:
            theWindow = [cart64KMatrix window];
            break;
        case 128:
            theWindow = [cart128KMatrix window];
            break;
        case 256:
            theWindow = [cart256KMatrix window];
            break;
        case 512:
            theWindow = [cart512KMatrix window];
            break;
        case 1024:
            theWindow = [cart1024KMatrix window];
            break;
        case 2048:
            theWindow = [cart2048KMatrix window];
            break;
        case 4096:
            theWindow = [cart4096KMatrix window];
            break;
        case 32768:
            theWindow = [cart32MMatrix window];
            break;
        case 65536:
            theWindow = [cart64MMatrix window];
            break;
        case 131072:
            theWindow = [cart128MMatrix window];
            break;
        default:
            return(CARTRIDGE_NONE);
        }
    cartType = [NSApp runModalForWindow:theWindow];
    return(cartType);             
}

/*------------------------------------------------------------------------------
*  cartSelectOK - This method handles the OK button from the cartridge selection
*     window, and sets the cartridge type appropriately.
*-----------------------------------------------------------------------------*/
- (IBAction)cartSelectOK:(id)sender 
{
    int cartSize = [sender tag];
    int cartType;
    
    switch(cartSize) {
        case 2:
            cartType = CART2KTYPES[[[cart2KMatrix selectedCell] tag]];
            break;
        case 4:
            cartType = CART4KTYPES[[[cart4KMatrix selectedCell] tag]];
            break;
        case 8:
            cartType = CART8KTYPES[[[cart8KMatrix selectedCell] tag]];
            break;
        case 16:
            cartType = CART16KTYPES[[[cart16KMatrix selectedCell] tag]];
            break;
        case 32:
            cartType = CART32KTYPES[[[cart32KMatrix selectedCell] tag]];
            break;
        case 40:
            cartType = CART40KTYPES[[[cart40KMatrix selectedCell] tag]];
            break;
        case 64:
            cartType = CART64KTYPES[[[cart64KMatrix selectedCell] tag]];
            break;
        case 128:
            cartType = CART128KTYPES[[[cart128KMatrix selectedCell] tag]];
            break;
        case 256:
            cartType = CART256KTYPES[[[cart256KMatrix selectedCell] tag]];
            break;
        case 512:
            cartType = CART512KTYPES[[[cart512KMatrix selectedCell] tag]];
            break;
        case 1024:
            cartType = CART1024KTYPES[[[cart1024KMatrix selectedCell] tag]];
            break;
        case 2048:
            cartType = CART2048KTYPES[[[cart2048KMatrix selectedCell] tag]];
            break;
        case 4096:
            cartType = CART4096KTYPES[[[cart4096KMatrix selectedCell] tag]];
            break;
        case 32768:
            cartType = CART32MTYPES[[[cart32MMatrix selectedCell] tag]];
            break;
        case 65536:
            cartType = CART64MTYPES[[[cart64MMatrix selectedCell] tag]];
            break;
        case 131072:
            cartType = CART128MTYPES[[[cart128MMatrix selectedCell] tag]];
            break;
        default:
            cartType = 0;
        }
    
    [NSApp stopModalWithCode:cartType];
    [[sender window] close];
}

/*------------------------------------------------------------------------------
*  cartSelectOK - This method handles the cancel button from the cartridge 
*     selection window, and sets the cartridge type appropriately.
*-----------------------------------------------------------------------------*/
- (IBAction)cartSelectCancel:(id)sender
{
    [NSApp stopModalWithCode:CARTRIDGE_NONE];
    [[sender window] close];
}

/*------------------------------------------------------------------------------
*  cassInsert - This method inserts a cassette image into the emulator
*-----------------------------------------------------------------------------*/
- (IBAction)cassInsert:(id)sender
{
    NSString *filename;
    char tapename[FILENAME_MAX+1];
    int ret = FALSE;
    
    PauseAudio(1);
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_cass_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:tapename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        ret = CASSETTE_Insert(tapename);
        if (! ret) 
            [self displayError:@"Unable to Insert Cassette!"];
        }
    PauseAudio(0);
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassInsertFile - This method inserts a cassette image into the emulator, 
*     given it's filename
*-----------------------------------------------------------------------------*/
- (void)cassInsertFile:(NSString *)filename
{
    char tapename[FILENAME_MAX+1];
    int ret = FALSE;
    
    if (filename != nil) {
        [filename getCString:tapename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        ret = CASSETTE_Insert(tapename);
        if (! ret) 
            [self displayError:@"Unable to Insert Cassette!"];
        }
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassRecord - This method presses the record button on the cassette drive.
*-----------------------------------------------------------------------------*/
- (IBAction)cassRecord:(id)sender
{
    CASSETTE_record = 1 - CASSETTE_record;
    [self updateMediaStatusWindow];
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassRemove - This method removes the inserted cassette.
*-----------------------------------------------------------------------------*/
- (IBAction)cassRemove:(id)sender
{
    CASSETTE_Remove();
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassRewind - This method rewinds the inserted cassette.
*-----------------------------------------------------------------------------*/
- (IBAction)cassRewind:(id)sender
{
    CASSETTE_Seek(1);
}


/*------------------------------------------------------------------------------
*  cassStatusProtect - This is called when a drive Lock/Unlock is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)cassStatusProtect:(id)sender
{
    CASSETTE_write_protect = 1 - CASSETTE_write_protect;
    [self updateMediaStatusWindow];
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  changeToComputer - This method switches to computer mode from 5200 mode.
*-----------------------------------------------------------------------------*/
- (void)changeToComputer
{
    int axlon_enabled, mosaic_enabled;
    
	CARTRIDGE_Remove();
	
    CalcMachineTypeRam(machine_switch_type, &Atari800_machine_type,
                       &MEMORY_ram_size, &axlon_enabled,
                       &mosaic_enabled, &ULTIMATE_enabled,
                       &Atari800_builtin_basic, &Atari800_builtin_game,
                       &Atari800_keyboard_leds, &Atari800_jumper_present);

    if (!axlon_enabled)
        MEMORY_axlon_num_banks = 0;
    else
        MEMORY_axlon_num_banks = PREFS_axlon_num_banks;

    if (!mosaic_enabled)
        MEMORY_mosaic_num_banks = 0;
    else
        MEMORY_mosaic_num_banks = PREFS_mosaic_num_banks;
	memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
	Atari_DisplayScreen((UBYTE *) Screen_atari);
    Atari800_InitialiseMachine();
    requestCaptionChange = 1;
}


/*------------------------------------------------------------------------------
*  convertCartRom - This method converts a .cart image into a ROM dump file.
*-----------------------------------------------------------------------------*/
- (IBAction)convertCartRom:(id)sender
{
    UBYTE* image;
    NSString *filename;
    Header header;
    char cfilename[FILENAME_MAX+1];
    int nbytes;
    FILE *f;
    
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        f = fopen(cfilename, "rb");
	if (!f) {
            [self displayError:@"Unable to Open Cartridge File!"];
            return;
            }
        image = malloc(CARTRIDGE_MAX_SIZE+1);
        if (image == NULL) {
            fclose(f);
            [self displayError:@"Unable to Create ROM Image!"];
            }
        nbytes = fread((char *) &header, 1, sizeof(Header), f);
        nbytes = fread(image, 1, CARTRIDGE_MAX_SIZE + 1, f);

        fclose(f);
        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]:@"rom"];
                
        if (filename == nil) {
            free(image);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	f = fopen(cfilename, "wb");
	if (f) {
            fwrite(image, 1, nbytes, f);
            fclose(f);
            }
	free(image);
	}
    
}

/*------------------------------------------------------------------------------
*  convertRomCart - This method converts a ROM dump file into a .cart image.
*-----------------------------------------------------------------------------*/
- (IBAction)convertRomCart:(id)sender
{
    UBYTE *image;
    int nbytes;
    Header header;
    int checksum;
    int type;
    FILE *f;
    NSString *filename;
    char cfilename[FILENAME_MAX+1];
    
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
	f = fopen(cfilename, "rb");
	if (!f) {
            [self displayError:@"Unable to Open ROM File!"];
            return;
            }
	image = malloc(CARTRIDGE_MAX_SIZE+1);
	if (image == NULL) {
            fclose(f);
            [self displayError:@"Unable to Create Cart File"];
            return;
            }
	nbytes = fread(image, 1, CARTRIDGE_MAX_SIZE + 1, f);
	fclose(f);
	if ((nbytes & 0x3ff) == 0) {
            type = [self cartSelect:(nbytes/1024)];
            if (type != CARTRIDGE_NONE) {
                checksum = CARTRIDGE_Checksum(image, nbytes);

                header.id[0] = 'C';
                header.id[1] = 'A';
                header.id[2] = 'R';
                header.id[3] = 'T';
                header.type[0] = (type >> 24) & 0xff;
                header.type[1] = (type >> 16) & 0xff;
                header.type[2] = (type >> 8) & 0xff;
                header.type[3] = type & 0xff;
                header.checksum[0] = (checksum >> 24) & 0xff;
                header.checksum[1] = (checksum >> 16) & 0xff;
                header.checksum[2] = (checksum >> 8) & 0xff;
                header.checksum[3] = checksum & 0xff;
                header.gash[0] = '\0';
                header.gash[1] = '\0';
                header.gash[2] = '\0';
                header.gash[3] = '\0';
                filename = [self saveFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]:@"car"];
                
                if (filename == nil) {
                    free(image);
                    return;
                    }
                    
                [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
                f = fopen(cfilename, "wb");
                if (f) {
                    fwrite(&header, 1, sizeof(header), f);
                    fwrite(image, 1, nbytes, f);
                    fclose(f);
		}
            }
	}
	free(image);
    }
}

/*------------------------------------------------------------------------------
*  createDisk - This method responds to the create disk button push in the disk
*     creation window, and actually creates the disk image.
*-----------------------------------------------------------------------------*/
- (IBAction)createDisk:(id)sender
{
    ULONG bytesInBootSector;
    ULONG bytesPerSector;
    ULONG sectors;
    ULONG imageLength;
    FILE *image = NULL;
    NSString *filename;
    char cfilename[FILENAME_MAX];
    struct AFILE_ATR_Header atrHeader;
    int diskMounted;
    int i;
    
    bytesInBootSector = ([diskFmtDDBytesPulldown indexOfSelectedItem] + 1) * 128;
	switch ([diskFmtCusBytesPulldown indexOfSelectedItem]) {
		case 0:
		default:
			bytesPerSector = 128;
			break;
		case 1:
			bytesPerSector = 256;
			break;
		case 2:
			bytesPerSector = 512;
			bytesInBootSector = 512;
			break;
	}
    sectors = [diskFmtCusSecField intValue];
    
    if (sectors <= 3)
        imageLength = sectors * bytesInBootSector / 16;
    else
        imageLength = ((sectors - 3) * bytesPerSector + 3 * bytesInBootSector) / 16;
 
    filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"atr"];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
        image = fopen(cfilename, "wb");
        if (image == NULL) {
            [self displayError:@"Unable to Create Disk Image!"];
            }
        else {
            atrHeader.magic1 = AFILE_ATR_MAGIC1;
            atrHeader.magic2 = AFILE_ATR_MAGIC2;
            atrHeader.secsizelo = bytesPerSector & 0x00ff;
            atrHeader.secsizehi = (bytesPerSector & 0xff00) >> 8;
            atrHeader.seccountlo = imageLength & 0x00ff;
            atrHeader.seccounthi = (imageLength & 0xff00) >> 8;
            atrHeader.hiseccountlo = (imageLength & 0x00ff0000) >> 16;
            atrHeader.hiseccounthi = (imageLength & 0xff000000) >> 24;
            for (i=0;i<8;i++)
                atrHeader.gash[i] = 0;
            atrHeader.writeprotect = 0;
            
            fwrite(&atrHeader, sizeof(struct AFILE_ATR_Header), 1, image);
            
            for (i = 0; i < imageLength; i++)
                fwrite("\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000",16,1,image);
                
            fflush(image);
            fclose(image);
            }
        }
        
    if ([diskFmtInsertNewButton state] == NSOnState) {
        diskMounted = SIO_Mount([diskFmtInsertDrivePulldown indexOfSelectedItem] + 1, cfilename, 0);
        if (!diskMounted)
            [self displayError:@"Unable to Mount Disk Image!"];
        [self updateInfo];
        }
    
    [NSApp stopModal];
    [[diskFmtMatrix window] close];
}

/*------------------------------------------------------------------------------
*  createHardDisk - This method responds to the create disk button push in the hard disk
*     creation window, and actually creates the disk image.
*-----------------------------------------------------------------------------*/
- (IBAction)createHardDisk:(id)sender;
{
    void *image;
    NSString *filename;
    NSString *fileType;
    int diskMounted;
    char cfilename[FILENAME_MAX];
    
    int sectors = [hardDiskFmtCusSecField intValue];
    int type = [[hardDiskFmtMatrix selectedCell] tag];
    
    if (type == 0)
        fileType = @"raw";
    else
        fileType = @"img";
    
    filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:fileType];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
        switch (type) {
            case 0:
                image = RAW_Init_New(cfilename, sectors);
                break;
            case 1:
            default:
                image = VHD_Init_New(cfilename, 4, 4, sectors, FALSE);
                break;
            case 2:
                image = VHD_Init_New(cfilename, 4, 4, sectors, TRUE);
                break;
        }
        if (image == NULL) {
            [self displayError:@"Unable to Create Disk Image!"];
            }
        else {
            VHD_Image_Close(image);
            if ([hardDiskFmtInsertNewButton state] == NSOnState) {
                strcpy(side2_compact_flash_filename, cfilename);
                if (SIDE2_enabled) {
                    diskMounted = SIDE2_Add_Block_Device(cfilename);
                    if (!diskMounted)
                        [self displayError:@"Unable to Mount Disk Image!"];
                    [self updateInfo];
                }
            }
        }
    }
    
    [NSApp stopModal];
    [[hardDiskFmtMatrix window] close];
}

/*------------------------------------------------------------------------------
*  createCassette - This method responds to the new cassette button in the 
*     media status window, or the new cassette menu item.
*-----------------------------------------------------------------------------*/
- (IBAction)createCassette:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX];
    
    PauseAudio(1);
    filename = [self saveFileInDirectory:[NSString stringWithCString:atari_cass_dir encoding:NSUTF8StringEncoding]:@"cas"];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
#if 1
        CASSETTE_CreateCAS(cfilename, "");
        [self updateInfo];
#else
        image = fopen(cfilename, "wb");
        if (image == NULL) {
            [self displayError:@"Unable to Create Cassette Image!"];
            }
        else {
            fclose(image);
            if (CASSETTE_status == CASSETTE_STATUS_NONE)
                CASSETTE_Remove();
			ret = CASSETTE_Insert(cfilename);
			if (! ret) 
				[self displayError:@"Unable to Insert Cassette!"];
			[self updateInfo];
			}
#endif
    }
}

/*------------------------------------------------------------------------------
*  diskInsert - This method inserts a floppy disk in the specified drive in
*     response to a menu.
*-----------------------------------------------------------------------------*/
- (IBAction)diskInsert:(id)sender
{
    int diskNum = [sender tag] - 1;
    int readOnly;
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int diskMounted;
    
    PauseAudio(1);
    readOnly = (SIO_drive_status[diskNum] == SIO_READ_ONLY ? TRUE : FALSE);
    filename = [self browseFileInDirectory:
                [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        if (diskDriveSound)
            [[NSSound soundNamed:@"close810snd"] play];
        SIO_Dismount(diskNum + 1);
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        diskMounted = SIO_Mount(diskNum + 1, cfilename, readOnly);
        if (!diskMounted)
            [self displayError:@"Unable to Mount Disk Image!"];
		else if (SIO_IsVapi(diskNum+1) && ESC_enable_sio_patch)
            [self displayError2:@"VAPI Images require SIO Patch to be":@" off!  Do so on Atari Tab of Preferences"];
        [self updateInfo];
        }
    PauseAudio(0);
}

/*------------------------------------------------------------------------------
*  diskRotate - This method rotates the floppy disks between drivers in
*     response to a menu.
*-----------------------------------------------------------------------------*/
- (IBAction)diskRotate:(id)sender
{
    SIO_RotateDisks();
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  diskInsertFile - This method inserts a floppy disk into drive 1, given its
*     filename.
*-----------------------------------------------------------------------------*/
- (void)diskInsertFile:(NSString *)filename
{
    int readOnly;
    char cfilename[FILENAME_MAX];
    int diskMounted;
    
    readOnly = (SIO_drive_status[0] == SIO_READ_ONLY ? TRUE : FALSE);
    if (filename != nil) {
        if (diskDriveSound)
            [[NSSound soundNamed:@"close810snd"] play];
        SIO_Dismount(1);
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        diskMounted = SIO_Mount(1, cfilename, readOnly);
        if (!diskMounted)
            [self displayError:@"Unable to Mount Disk Image!"];
        [self updateInfo];
        Atari800_Coldstart();
        }
}

/*------------------------------------------------------------------------------
*  diskNoInsertFile - This method inserts a floppy disk into a drive, given its
*     filename and the drives number.
*-----------------------------------------------------------------------------*/
- (void)diskNoInsertFile:(NSString *)filename:(int) driveNo
{
    int readOnly;
    char cfilename[FILENAME_MAX];
    int diskMounted;
    
    readOnly = (SIO_drive_status[driveNo] == SIO_READ_ONLY ? TRUE : FALSE);
    if (filename != nil) {
        if (diskDriveSound)
            [[NSSound soundNamed:@"close810snd"] play];
        SIO_Dismount(driveNo+1);
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        diskMounted = SIO_Mount(driveNo+1, cfilename, readOnly);
        if (!diskMounted)
            [self displayError:@"Unable to Mount Disk Image!"];
		else if (SIO_IsVapi(driveNo+1) && ESC_enable_sio_patch)
            [self displayError2:@"VAPI Images require SIO Patch to be":@" off!  Do so on Atari Tab of Preferences"];
        [self updateInfo];
        }
}

/*------------------------------------------------------------------------------
*  diskInsertKey - This method inserts a floppy disk in the specified drive in
*     response to a keyboard shortcut.
*-----------------------------------------------------------------------------*/
- (IBAction)diskInsertKey:(int)diskNum
{
    int readOnly;
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int diskMounted;
	static NSString *num[8] = {@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8"};
    
    PauseAudio(1);
    readOnly = (SIO_drive_status[diskNum] == SIO_READ_ONLY ? TRUE : FALSE);
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        if (diskDriveSound)
            [[NSSound soundNamed:@"close810snd"] play];
        SIO_Dismount(diskNum);
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        diskMounted = SIO_Mount(diskNum, cfilename, readOnly);
        if (!diskMounted)
            [self displayError:@"Unable to Mount Disk Image!"];
		else if (SIO_IsVapi(diskNum) && ESC_enable_sio_patch)
            [self displayError2:@"VAPI Images require SIO Patch to be":@" off!  Do so on Atari Tab of Preferences"];
        [self updateInfo];
        }
    PauseAudio(0);
    [[KeyMapper sharedInstance] releaseCmdKeys:num[diskNum-1]];
}

/*------------------------------------------------------------------------------
*  diskRemove - This method removes a floppy disk in the specified drive in
*     response to a menu.
*-----------------------------------------------------------------------------*/
- (IBAction)diskRemove:(id)sender
{
    int diskNum = [sender tag] - 1;

    if (diskDriveSound)
        [[NSSound soundNamed:@"open810snd"] play];
    SIO_Dismount(diskNum + 1);
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  diskRemoveKey - This method removes a floppy disk in the specified drive in
*     response to a keyboard shortcut.
*-----------------------------------------------------------------------------*/
- (IBAction)diskRemoveKey:(int)diskNum
{
    if (diskDriveSound)
        [[NSSound soundNamed:@"open810snd"] play];
    SIO_Dismount(diskNum );
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  diskRemoveAll - This method removes disks from all of the floppy drives.
*-----------------------------------------------------------------------------*/
- (IBAction)diskRemoveAll:(id)sender
{
    int i;

    for (i=0;i<8;i++)
        SIO_Dismount(i + 1);
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  Save - This method saves the names of the mounted disks to a file
*      chosen by the user.
*-----------------------------------------------------------------------------*/
- (IBAction)diskSetSave:(id)sender
{
    NSString *filename;
    char *diskfilename;
    char dirname[FILENAME_MAX];
    char cfilename[FILENAME_MAX+1];
    FILE *f;
    int i;

    filename = [self saveFileInDirectory:[NSString stringWithCString:atari_diskset_dir encoding:NSUTF8StringEncoding]:@"set"];
    
    if (filename == nil)
        return;
                    
    [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];

    getcwd(dirname, FILENAME_MAX);

    f = fopen(cfilename, "w");
    if (f) {
        for (i=0;i<8;i++) {
			if (strncmp(SIO_filename[i], dirname, strlen(dirname)) == 0)
				diskfilename = &SIO_filename[i][strlen(dirname)+1];
			else
				diskfilename = SIO_filename[i];
		
            fputs(diskfilename,f);
            fprintf(f,"\n");
            }
        fclose(f);
        }
}

/*------------------------------------------------------------------------------
*  diskSetLoad - This method mounts the set of disk images from a file
*      chosen by the user.
*-----------------------------------------------------------------------------*/
- (IBAction)diskSetLoad:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX+1];
    char diskname[FILENAME_MAX+1];
    FILE *f;
    int i, mounted, readOnly;
    int numMountErrors = 0;
    int mountErrors[8];

    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_diskset_dir encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"set",@"SET", nil]];
    
    if (filename == nil)
        return;
    
    [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
    f = fopen(cfilename, "r");
    if (f) {
        for (i=0;i<8;i++) {
			if (Atari800_machine_type == Atari800_MACHINE_5200)
				[self changeToComputer];
            fgets(diskname,FILENAME_MAX,f);
            if (strlen(diskname) != 0)
                diskname[strlen(diskname)-1] = 0;
            if ((strcmp(diskname,"Off") != 0) && (strcmp(diskname,"Empty") != 0)) {
                readOnly = (SIO_drive_status[i] == SIO_READ_ONLY ? TRUE : FALSE);
                SIO_Dismount(i+1);
                mounted = SIO_Mount(i+1, diskname, readOnly);
                if (!mounted) {
                    numMountErrors++;
                    mountErrors[i] = 1;
                    }
                else
                    mountErrors[i] = 0;
                }
            else
                mountErrors[i] = 0;
            }
        fclose(f);
        if (numMountErrors != 0) 
            [self displayError:@"Unable to Mount Disk Image!"];
        [self updateInfo];
        }
}

/*------------------------------------------------------------------------------
*  diskSetLoad - This method mounts the set of disk images from a file
*      specified by the filename parameter.
*-----------------------------------------------------------------------------*/
- (IBAction)diskSetLoadFile:(NSString *)filename
{
    char cfilename[FILENAME_MAX+1];
    char diskname[FILENAME_MAX+1];
    FILE *f;
    int i, readOnly;

    [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
    f = fopen(cfilename, "r");
    if (f) {
        for (i=0;i<8;i++) {
            fgets(diskname,FILENAME_MAX,f);
            if (strlen(diskname) != 0)
                diskname[strlen(diskname)-1] = 0;
            if ((strcmp(diskname,"Off") != 0) && (strcmp(diskname,"Empty") != 0)) {
                readOnly = (SIO_drive_status[i] == SIO_READ_ONLY ? TRUE : FALSE);
                SIO_Dismount(i+1);
                SIO_Mount(i+1, diskname, readOnly);
                }
            }
        fclose(f);
        [self updateInfo];
        }
}

/*------------------------------------------------------------------------------
*  driveStatusChange - This method handles changes in the drive status controls 
*     in the disk management window.
*-----------------------------------------------------------------------------*/
- (IBAction)driveStatusChange:(id)sender
{
    int diskNum = [sender tag] - 1;
    char tempFilename[FILENAME_MAX];
    int readOnly;
    
    readOnly = (SIO_drive_status[diskNum] == SIO_READ_ONLY ? TRUE : FALSE);
    
    switch([sender indexOfSelectedItem]) {
        case 0:
            if (SIO_drive_status[diskNum] == SIO_READ_ONLY || SIO_drive_status[diskNum] == SIO_READ_WRITE) 
                SIO_Dismount(diskNum+1);
            SIO_DisableDrive(diskNum+1);
            break;
        case 1:
            if (SIO_drive_status[diskNum] == SIO_READ_ONLY || SIO_drive_status[diskNum] == SIO_READ_WRITE) 
                SIO_Dismount(diskNum+1);
            else {
                SIO_drive_status[diskNum] = SIO_NO_DISK;
                strcpy(SIO_filename[diskNum],"Empty");
                }
            break;
        case 2:
            if (SIO_drive_status[diskNum] == SIO_READ_WRITE) {
                strcpy(tempFilename, SIO_filename[diskNum]);
                SIO_Dismount(diskNum+1);
                SIO_Mount(diskNum+1, tempFilename, TRUE);
                }
            else
                [sender selectItemAtIndex:SIO_drive_status[diskNum]];
            break;
        case 3:
            if (SIO_drive_status[diskNum] == SIO_READ_ONLY) {
                strcpy(tempFilename, SIO_filename[diskNum]);
                SIO_Dismount(diskNum+1);
                SIO_Mount(diskNum+1, tempFilename, FALSE);
                }
            else
                [sender selectItemAtIndex:SIO_drive_status[diskNum]];
            break;
        }
    [self updateInfo];
}

/*------------------------------------------------------------------------------
*  loadExeFile - This method loads an Atari executable file into the emulator.
*-----------------------------------------------------------------------------*/
- (IBAction)loadExeFile:(id)sender
{
    NSString *filename;
    char exename[FILENAME_MAX+1];
    int ret = FALSE;
    
    PauseAudio(1);
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_exe_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:exename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        ret = BINLOAD_Loader(exename);
        if (! ret) 
            [self displayError:@"Unable to Load Binary/BASIC File!"];
    }
    PauseAudio(0);
    [[KeyMapper sharedInstance] releaseCmdKeys:@"r"];
	
}

/*------------------------------------------------------------------------------
*  loadExeFileFile - This method loads an Atari executable file into the 
*       emulator given its filename.
*-----------------------------------------------------------------------------*/
- (void)loadExeFileFile:(NSString *)filename
{
    char exename[FILENAME_MAX+1];
    int ret = FALSE;
    
    if (filename != nil) {
        if (Atari800_machine_type == Atari800_MACHINE_5200)
			[self changeToComputer];
        [filename getCString:exename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        ret = BINLOAD_Loader(exename);
        if (! ret) 
            [self displayError:@"Unable to Load Binary/BASIC File!"];
    }
}


/*------------------------------------------------------------------------------
*  hardSecUpdate - This method handles control updates in the hard disk image creation
*     window.
*-----------------------------------------------------------------------------*/
- (IBAction)hardSecUpdate:(id)sender
{
    int sectors = [hardDiskFmtCusSecField intValue];
    [hardDiskFmtCusMBField setIntValue:(sectors/(2*1024))];
}

/*------------------------------------------------------------------------------
*  hardMBUpdate - This method handles control updates in the hard disk image creation
*     window.
*-----------------------------------------------------------------------------*/
- (IBAction)hardMBUpdate:(id)sender
{
    int mbs = [hardDiskFmtCusMBField intValue];
    [hardDiskFmtCusSecField setIntValue:(mbs*2*1024)];
}

/*------------------------------------------------------------------------------
*  miscUpdate - This method handles control updates in the disk image creation
*     window.
*-----------------------------------------------------------------------------*/
- (IBAction)miscUpdate:(id)sender
{
    if (sender == diskFmtMatrix) {
        switch([[diskFmtMatrix selectedCell] tag]) {
            case 0:
                [diskFmtCusBytesPulldown selectItemAtIndex:0];
                [diskFmtCusSecField setIntValue:720];
                [diskFmtDDBytesPulldown selectItemAtIndex:0];
                [diskFmtCusBytesPulldown setEnabled:NO];
                [diskFmtCusSecField setEnabled:NO];
                [diskFmtDDBytesPulldown setEnabled:NO];
                break;
            case 1:
                [diskFmtCusBytesPulldown selectItemAtIndex:0];
                [diskFmtCusSecField setIntValue:1040];
                [diskFmtDDBytesPulldown selectItemAtIndex:0];
                [diskFmtCusBytesPulldown setEnabled:NO];
                [diskFmtCusSecField setEnabled:NO];
                [diskFmtDDBytesPulldown setEnabled:NO];
                break;
            case 2:
                [diskFmtCusBytesPulldown selectItemAtIndex:1];
                [diskFmtCusSecField setIntValue:720];
                [diskFmtDDBytesPulldown selectItemAtIndex:0];
                [diskFmtCusBytesPulldown setEnabled:NO];
                [diskFmtCusSecField setEnabled:NO];
                [diskFmtDDBytesPulldown setEnabled:YES];
                break;
            case 3:
                [diskFmtCusBytesPulldown setEnabled:YES];
                [diskFmtCusSecField setEnabled:YES];
                [diskFmtDDBytesPulldown setEnabled:YES];
                break;
            }
        }
    else if (sender == diskFmtInsertNewButton) {
        if ([diskFmtInsertNewButton state] == NSOnState)
            [diskFmtInsertDrivePulldown setEnabled:YES];
        else
            [diskFmtInsertDrivePulldown setEnabled:NO];        
        }
}

/*------------------------------------------------------------------------------
*  ok - This method handles the OK button press from the disk managment window.
*-----------------------------------------------------------------------------*/
- (IBAction)ok:(id)sender
{
    [NSApp stopModal];
    [[d1DiskField window] close];
    PauseAudio(0);
}

/*------------------------------------------------------------------------------
*  errorOK - This method handles the OK button press from the error window.
*-----------------------------------------------------------------------------*/
- (IBAction)errorOK:(id)sender;
{
    [NSApp stopModal];
    [[errorButton window] close];
}

/*------------------------------------------------------------------------------
*  error2OK - This method handles the OK button press from the error2 window.
*-----------------------------------------------------------------------------*/
- (IBAction)error2OK:(id)sender;
{
    [NSApp stopModal];
    [[error2Button window] close];
}

/*------------------------------------------------------------------------------
*  showCreatePanel - This method displays a window which allows the creation of
*     blank floppy images.
*-----------------------------------------------------------------------------*/
- (IBAction)showCreatePanel:(id)sender
{
    int driveNo;

    [diskFmtMatrix selectCellWithTag:0];
    [diskFmtCusBytesPulldown setEnabled:NO];
    [diskFmtCusSecField setEnabled:NO];
    [diskFmtDDBytesPulldown setEnabled:NO];
    for (driveNo=0;driveNo<8;driveNo++) {
        if (SIO_drive_status[driveNo] == SIO_NO_DISK ||
            SIO_drive_status[driveNo] == SIO_OFF)
            break;
        }
    if (driveNo == 8)
        driveNo = 0;
    [diskFmtInsertDrivePulldown selectItemAtIndex:driveNo];
    [diskFmtInsertDrivePulldown setEnabled:NO];
    [diskFmtCusBytesPulldown selectItemAtIndex:0];
    [diskFmtCusSecField setIntValue:720];
    [diskFmtDDBytesPulldown selectItemAtIndex:0];
    [diskFmtInsertNewButton setState:NSOffState];
    [NSApp runModalForWindow:[diskFmtMatrix window]];
    [[KeyMapper sharedInstance] releaseCmdKeys:@"n"];
}

/*------------------------------------------------------------------------------
*  showHardCreatePanel - This method displays a window which allows the creation of
*     blank hard disk images.
*-----------------------------------------------------------------------------*/
- (IBAction)showHardCreatePanel:(id)sender
{
    [hardDiskFmtMatrix selectCellWithTag:1];
    [hardDiskFmtCusSecField setIntValue:(64*2*1024)];
    [hardDiskFmtCusMBField setIntValue:64];
    [diskFmtInsertNewButton setState:NSOffState];
    [NSApp runModalForWindow:[hardDiskFmtMatrix window]];
}

/*------------------------------------------------------------------------------
*  showManagementPanel - This method displays the disk management window for
*     managing the Atari floppy drives.
*-----------------------------------------------------------------------------*/
- (IBAction)showManagementPanel:(id)sender
{
	int i;
	
    [self updateInfo];
    PauseAudio(1);
	numChecked = 0;
	for (i=0;i<8;i++)
		checks[i] = 0;
	[d1SwitchButton setState:NSOffState];
	[d2SwitchButton setState:NSOffState];
	[d3SwitchButton setState:NSOffState];
	[d4SwitchButton setState:NSOffState];
	[d5SwitchButton setState:NSOffState];
	[d6SwitchButton setState:NSOffState];
	[d7SwitchButton setState:NSOffState];
	[d8SwitchButton setState:NSOffState];
    [NSApp runModalForWindow:[d1DiskField window]];
    [[KeyMapper sharedInstance] releaseCmdKeys:@"d"];
}

/*------------------------------------------------------------------------------
*  showSectorPanel - This method displays the sector editor window
*-----------------------------------------------------------------------------*/
- (IBAction)showSectorPanel:(id)sender
{
	NSString *filename;

    PauseAudio(1);
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:
				  [NSArray arrayWithObjects:@"atr",@"ATR", nil]];
    if (filename != nil) {
		if ([DiskEditorWindow isAlreadyOpen:filename] != nil) {
			[self displayError:@"Image already open in disk editor!"];
			}
		else if ([[SectorEditorWindow sharedInstance] mountDisk:filename] == -1) {
			[self displayError:@"Unable to open disk image!"];
			}
		else {
			[[SectorEditorWindow sharedInstance] showSectorPanel];
			}
		}
	PauseAudio(0);
    [[KeyMapper sharedInstance] releaseCmdKeys:@"e"];
}

/*------------------------------------------------------------------------------
*  showEditorPanel - This method displays the disk image editor window
*-----------------------------------------------------------------------------*/
- (IBAction)showEditorPanel:(id)sender
{
	NSWindowController *controller;
	NSString *filename;
	DiskEditorDataSource *dataSource;
	DiskEditorWindow *diskEditor;
	NSString *errorString;

    [[DisplayManager sharedInstance] enableMacCopyPaste];
    PauseAudio(1);
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:
				  [NSArray arrayWithObjects:@"atr",@"ATR", nil]];
    if (filename != nil) {
		diskEditor = [DiskEditorWindow isAlreadyOpen:filename];
		// printf("Disk Editor = %x\n",diskEditor);
		if (diskEditor != nil)
			[[diskEditor window]  makeKeyAndOrderFront:self];
		else {
			dataSource = [[DiskEditorDataSource alloc] init];
			//printf("Editor here 1\n");
			errorString = [dataSource mountDisk:filename];
			//printf("Editor here 2\n");
			if (errorString == nil) {
			if ([[Preferences sharedInstance] getBrushed]) {
					controller = [[DiskEditorWindow alloc] 
								initWithWindowNibName:@"DiskEditorWindowBrushed":
									dataSource:filename];
				}
				else {
				controller = [[DiskEditorWindow alloc] 
								initWithWindowNibName:@"DiskEditorWindow":
									dataSource:filename];
				}
				//printf("Controller = %x\n",controller);
				[controller showWindow:self];
				}
			else {
				[self displayError:errorString];
				}
			}
        }
			//printf("Editor here 3\n");
    PauseAudio(0);
    [[DisplayManager sharedInstance] enableAtariCopyPaste];
    [[KeyMapper sharedInstance] releaseCmdKeys:@"e"];
}

/*------------------------------------------------------------------------------
*  diskStatusChange - This is called when a drive Insert/Eject is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)diskStatusChange:(id)sender
{
	int driveNo = [sender tag];
	
	if (showUpperDrives)
		driveNo += 4;
	
	if (SIO_drive_status[driveNo] == SIO_NO_DISK) {
		[self diskInsertKey:(driveNo+1)];
		}
	else {
		[self diskRemoveKey:(driveNo+1)];
		}
}

/*------------------------------------------------------------------------------
*  diskDisplayChange - This is called when the 1-4 or 5-8 buttons are pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)diskDisplayChange:(id)sender
{
	showUpperDrives = [[driveSelectMatrix selectedCell] tag];
	[d1DiskImageSectorField setStringValue:@""];
	[d2DiskImageSectorField setStringValue:@""];
	[d3DiskImageSectorField setStringValue:@""];
	[d4DiskImageSectorField setStringValue:@""];
	[self updateInfo];
}

/*------------------------------------------------------------------------------
*  diskStatusPower - This is called when a drive On/Off is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)diskStatusPower:(id)sender
{
	int driveNo = [sender tag];
	
	if (showUpperDrives)
		driveNo += 4;
		
	if (SIO_drive_status[driveNo] == SIO_OFF) {
		SIO_drive_status[driveNo] = SIO_NO_DISK;
        strcpy(SIO_filename[driveNo],"Empty");
        [[NSSound soundNamed:@"open810snd"] play];
		}
	else {
		if (SIO_drive_status[driveNo] == SIO_READ_ONLY || SIO_drive_status[driveNo] == SIO_READ_WRITE) 
			SIO_Dismount(driveNo+1);
		SIO_DisableDrive(driveNo+1);
        [[NSSound soundNamed:@"close810snd"] play];
		}
	[self updateInfo];
}

/*------------------------------------------------------------------------------
*  diskStatusProtect - This is called when a drive Lock/Unlock is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)diskStatusProtect:(id)sender
{
    char tempFilename[FILENAME_MAX];
	int driveNo = [sender tag];
	int status;
	
	if (showUpperDrives)
		driveNo += 4;

	status = SIO_drive_status[driveNo];
	
    strcpy(tempFilename, SIO_filename[driveNo]);
	SIO_Dismount(driveNo+1);
	
	if (status == SIO_READ_WRITE) {
		SIO_Mount(driveNo+1, tempFilename, TRUE);
		}
	else {
		SIO_Mount(driveNo+1, tempFilename, FALSE);
		}
	[self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassStatusChange - This is called when a cassette load/unload is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)cassStatusChange:(id)sender
{
    if (CASSETTE_status == CASSETTE_STATUS_NONE)
        {
        [self cassInsert:self];
		}
	else {
		[self cassRemove:self];
		}
}

/*------------------------------------------------------------------------------
*  cartStatusChange - This is called when a cartridge load/unload is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)cartStatusChange:(id)sender
{
    if (ULTIMATE_enabled) {
        if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE) {
            [self cartInsert:self];
            }
        else {
            [self cartRemove:self];
            }

    } else {
        if (CARTRIDGE_main.type == CARTRIDGE_NONE) {
            [self cartInsert:self];
            }
        else {
            [self cartRemove:self];
            }
    }
}

/*------------------------------------------------------------------------------
*  cartSecondStatusChange - This is called when a cartridge load/unload 
*    is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)cartSecondStatusChange:(id)sender
{
    if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE) {
		[self cartSecondInsert:self];
		}
	else {
		[self cartSecondRemove:self];
		}
}

/*------------------------------------------------------------------------------
*  updateMediaStatusWindow - Update the media status window when something
*      changes.
*-----------------------------------------------------------------------------*/
- (void) updateMediaStatusWindow
{
	char *ptr;
	int driveOffset;
	
	if (Devices_enable_d_patch) {
		showUpperDrives = FALSE;
		[[driveSelectMatrix cellWithTag:1] setEnabled:NO];
		[driveSelectMatrix selectCellWithTag:0];
	} else {
		[[driveSelectMatrix cellWithTag:1] setEnabled:YES];
	}

	if (Devices_enable_p_patch)
		{
		[selectPrinterPulldown setEnabled:YES];
		[selectTextMenuItem setTarget:[PrintOutputController sharedInstance]];
		[selectAtari825MenuItem setTarget:[PrintOutputController sharedInstance]];
		[selectAtari1020MenuItem setTarget:[PrintOutputController sharedInstance]];
        [selectEpsonMenuItem setTarget:[PrintOutputController sharedInstance]];
        [selectAtasciiMenuItem setTarget:[PrintOutputController sharedInstance]];
		switch(currPrinter)
			{
			case 0:
				[printerImageNameField setStringValue:@"Text"];
				[printerImageView setImage:textImage];
				[printerPreviewItem setTarget:nil];
				[printerPreviewButton setEnabled:NO];
				[selectTextItem setState:NSOnState];
				[selectAtari825Item setState:NSOffState];
				[selectAtari1020Item setState:NSOffState];
				[selectEpsonItem setState:NSOffState];
                [selectAtasciiItem setState:NSOffState];
				[resetPrinterItem setTarget:nil];
				[resetPrinterMenuItem setTarget:nil];
				break;
			case 1:
				[printerImageNameField setStringValue:@"Atari 825"];
				[printerImageView setImage:atari825Image];
				[printerPreviewItem setTarget:[PrintOutputController sharedInstance]];
				[printerPreviewButton setEnabled:YES];
				[selectTextItem setState:NSOffState];
				[selectAtari825Item setState:NSOnState];
				[selectAtari1020Item setState:NSOffState];
				[selectEpsonItem setState:NSOffState];
                [selectAtasciiItem setState:NSOffState];
				[resetPrinterItem setTarget:[PrintOutputController sharedInstance]];
				[resetPrinterMenuItem setTarget:[PrintOutputController sharedInstance]];
				break;
			case 2:
				[printerImageNameField setStringValue:@"Atari 1020"];
				[printerImageView setImage:atari1020Image];
				[printerPreviewItem setTarget:[PrintOutputController sharedInstance]];
				[printerPreviewButton setEnabled:YES];
				[selectTextItem setState:NSOffState];
				[selectAtari825Item setState:NSOffState];
				[selectAtari1020Item setState:NSOnState];
				[selectEpsonItem setState:NSOffState];
                [selectAtasciiItem setState:NSOffState];
				[resetPrinterItem setTarget:[PrintOutputController sharedInstance]];
				[resetPrinterMenuItem setTarget:[PrintOutputController sharedInstance]];
				break;
			case 3:
				[printerImageNameField setStringValue:@"Epson FX80"];
				[printerImageView setImage:epsonImage];
				[printerPreviewItem setTarget:[PrintOutputController sharedInstance]];
				[printerPreviewButton setEnabled:YES];
				[selectTextItem setState:NSOffState];
				[selectAtari825Item setState:NSOffState];
				[selectAtari1020Item setState:NSOffState];
				[selectEpsonItem setState:NSOnState];
                [selectAtasciiItem setState:NSOffState];
				[resetPrinterItem setTarget:[PrintOutputController sharedInstance]];
				[resetPrinterMenuItem setTarget:[PrintOutputController sharedInstance]];
				break;
            case 4:
                [printerImageNameField setStringValue:@"ATASCII"];
                [printerImageView setImage:atasciiImage];
                [printerPreviewItem setTarget:[PrintOutputController sharedInstance]];
                [printerPreviewButton setEnabled:YES];
                [selectTextItem setState:NSOffState];
                [selectAtari825Item setState:NSOffState];
                [selectAtari1020Item setState:NSOffState];
                [selectEpsonItem setState:NSOffState];
                [selectAtasciiItem setState:NSOnState];
                [resetPrinterItem setTarget:[PrintOutputController sharedInstance]];
                [resetPrinterMenuItem setTarget:[PrintOutputController sharedInstance]];
                break;
			}
		}
	else
		{
		[printerImageNameField setStringValue:@"No Printer"];
		[printerImageView setImage:nil];
		[printerPreviewButton setEnabled:NO];
		[printerPreviewItem setTarget:nil];
		[selectPrinterPulldown setEnabled:NO];
		[selectTextMenuItem setTarget:nil];
		[selectAtari825MenuItem setTarget:nil];
		[selectAtari1020MenuItem setTarget:nil];
		[selectEpsonMenuItem setTarget:nil];
		[resetPrinterMenuItem setTarget:nil];
		}

	
	if (showUpperDrives) { 
	    driveOffset = 4;
		[d1DiskImageNumberField setStringValue:@"D5"];
		[d2DiskImageNumberField setStringValue:@"D6"];
		[d3DiskImageNumberField setStringValue:@"D7"];
		[d4DiskImageNumberField setStringValue:@"D8"];
		}
	else {
	    driveOffset = 0;
		[d1DiskImageNumberField setStringValue:@"D1"];
		[d2DiskImageNumberField setStringValue:@"D2"];
		[d3DiskImageNumberField setStringValue:@"D3"];
		[d4DiskImageNumberField setStringValue:@"D4"];
		}
	
	switch(SIO_drive_status[0+driveOffset]) {
		case SIO_OFF:
			[d1DiskImageNameField setStringValue:@"Off"];
			[d1DiskImagePowerButton setTitle:@"On"];
			[d1DiskImageInsertButton setTitle:@"Insert"];
			[d1DiskImageInsertButton setEnabled:NO];
			[d1DiskImageProtectButton setTitle:@"Lock"];
			[d1DiskImageProtectButton setEnabled:NO];
			[d1DiskImageView setImage:off810Image];
			[d1DiskImageLockView setImage:lockoffImage];
			break;
			[d1DiskImageSectorField setStringValue:@""];
		case SIO_NO_DISK:
			[d1DiskImageNameField setStringValue:@"Empty"];
			[d1DiskImagePowerButton setTitle:@"Off"];
			[d1DiskImageInsertButton setTitle:@"Insert"];
			[d1DiskImageInsertButton setEnabled:YES];
			[d1DiskImageProtectButton setTitle:@"Lock"];
			[d1DiskImageProtectButton setEnabled:NO];
			[d1DiskImageView setImage:empty810Image];
			[d1DiskImageLockView setImage:lockoffImage];
			[d1DiskImageSectorField setStringValue:@""];
			break;
		case SIO_READ_WRITE:
		case SIO_READ_ONLY:
			ptr = SIO_filename[0+driveOffset] + 
					strlen(SIO_filename[0+driveOffset]) - 1;
			while (ptr > SIO_filename[0+driveOffset]) {
				if (*ptr == '/') {
					ptr++;
					break;
					}
				ptr--;
				}
			[d1DiskImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
			[d1DiskImagePowerButton setTitle:@"Off"];
			[d1DiskImageInsertButton setTitle:@"Eject"];
			[d1DiskImageInsertButton setEnabled:YES];
			if (SIO_drive_status[0+driveOffset] == SIO_READ_WRITE) {
				[d1DiskImageProtectButton setTitle:@"Lock"];
				[d1DiskImageLockView setImage:lockoffImage];
				}
			else {
				[d1DiskImageProtectButton setTitle:@"Unlk"];
				[d1DiskImageLockView setImage:lockImage];
				}
			[d1DiskImageProtectButton setEnabled:YES];
			[d1DiskImageView setImage:closed810Image];
			break;
		}
	switch(SIO_drive_status[1+driveOffset]) {
		case SIO_OFF:
			[d2DiskImageNameField setStringValue:@"Off"];
			[d2DiskImagePowerButton setTitle:@"On"];
			[d2DiskImageInsertButton setTitle:@"Insert"];
			[d2DiskImageInsertButton setEnabled:NO];
			[d2DiskImageProtectButton setTitle:@"Lock"];
			[d2DiskImageProtectButton setEnabled:NO];
			[d2DiskImageView setImage:off810Image];
			[d2DiskImageLockView setImage:lockoffImage];
			[d2DiskImageSectorField setStringValue:@""];
			break;
		case SIO_NO_DISK:
			[d2DiskImageNameField setStringValue:@"Empty"];
			[d2DiskImagePowerButton setTitle:@"Off"];
			[d2DiskImageInsertButton setTitle:@"Insert"];
			[d2DiskImageInsertButton setEnabled:YES];
			[d2DiskImageProtectButton setTitle:@"Lock"];
			[d2DiskImageProtectButton setEnabled:NO];
			[d2DiskImageView setImage:empty810Image];
			[d2DiskImageLockView setImage:lockoffImage];
			[d2DiskImageSectorField setStringValue:@""];
			break;
		case SIO_READ_WRITE:
		case SIO_READ_ONLY:
			ptr = SIO_filename[1+driveOffset] + 
					strlen(SIO_filename[1+driveOffset]) - 1;
			while (ptr > SIO_filename[1+driveOffset]) {
				if (*ptr == '/') {
					ptr++;
					break;
					}
				ptr--;
				}
			[d2DiskImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
			[d2DiskImagePowerButton setTitle:@"Off"];
			[d2DiskImageInsertButton setTitle:@"Eject"];
			[d2DiskImageInsertButton setEnabled:YES];
			if (SIO_drive_status[1+driveOffset] == SIO_READ_WRITE) {
				[d2DiskImageProtectButton setTitle:@"Lock"];
				[d2DiskImageLockView setImage:lockoffImage];
				}
			else {
				[d2DiskImageProtectButton setTitle:@"Unlk"];
				[d2DiskImageLockView setImage:lockImage];
				}
			[d2DiskImageProtectButton setEnabled:YES];
			[d2DiskImageView setImage:closed810Image];
			break;
		}
	switch(SIO_drive_status[2+driveOffset]) {
		case SIO_OFF:
			[d3DiskImageNameField setStringValue:@"Off"];
			[d3DiskImagePowerButton setTitle:@"On"];
			[d3DiskImageInsertButton setTitle:@"Insert"];
			[d3DiskImageInsertButton setEnabled:NO];
			[d3DiskImageProtectButton setTitle:@"Lock"];
			[d3DiskImageProtectButton setEnabled:NO];
			[d3DiskImageView setImage:off810Image];
			[d3DiskImageLockView setImage:lockoffImage];
			[d3DiskImageSectorField setStringValue:@""];
			break;
		case SIO_NO_DISK:
			[d3DiskImageNameField setStringValue:@"Empty"];
			[d3DiskImagePowerButton setTitle:@"Off"];
			[d3DiskImageInsertButton setTitle:@"Insert"];
			[d3DiskImageInsertButton setEnabled:YES];
			[d3DiskImageProtectButton setTitle:@"Lock"];
			[d3DiskImageProtectButton setEnabled:NO];
			[d3DiskImageView setImage:empty810Image];
			[d3DiskImageLockView setImage:lockoffImage];
			[d3DiskImageSectorField setStringValue:@""];
			break;
		case SIO_READ_WRITE:
		case SIO_READ_ONLY:
			ptr = SIO_filename[2+driveOffset] + 
					strlen(SIO_filename[2+driveOffset]) - 1;
			while (ptr > SIO_filename[2+driveOffset]) {
				if (*ptr == '/') {
					ptr++;
					break;
					}
				ptr--;
				}
			[d3DiskImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
			[d3DiskImagePowerButton setTitle:@"Off"];
			[d3DiskImageInsertButton setTitle:@"Eject"];
			[d3DiskImageInsertButton setEnabled:YES];
			if (SIO_drive_status[2+driveOffset] == SIO_READ_WRITE) {
				[d3DiskImageProtectButton setTitle:@"Lock"];
				[d3DiskImageLockView setImage:lockoffImage];
				}
			else {
				[d3DiskImageProtectButton setTitle:@"Unlk"];
				[d3DiskImageLockView setImage:lockImage];
				}
			[d3DiskImageProtectButton setEnabled:YES];
			[d3DiskImageView setImage:closed810Image];
			break;
		}
	switch(SIO_drive_status[3+driveOffset]) {
		case SIO_OFF:
			[d4DiskImageNameField setStringValue:@"Off"];
			[d4DiskImagePowerButton setTitle:@"On"];
			[d4DiskImageInsertButton setTitle:@"Insert"];
			[d4DiskImageInsertButton setEnabled:NO];
			[d4DiskImageProtectButton setTitle:@"Lock"];
			[d4DiskImageProtectButton setEnabled:NO];
			[d4DiskImageView setImage:off810Image];
			[d4DiskImageLockView setImage:lockoffImage];
			[d4DiskImageSectorField setStringValue:@""];
			break;
		case SIO_NO_DISK:
			[d4DiskImageNameField setStringValue:@"Empty"];
			[d4DiskImagePowerButton setTitle:@"Off"];
			[d4DiskImageInsertButton setTitle:@"Insert"];
			[d4DiskImageInsertButton setEnabled:YES];
			[d4DiskImageProtectButton setTitle:@"Lock"];
			[d4DiskImageProtectButton setEnabled:NO];
			[d4DiskImageView setImage:empty810Image];
			[d4DiskImageLockView setImage:lockoffImage];
			[d4DiskImageSectorField setStringValue:@""];
			break;
		case SIO_READ_WRITE:
		case SIO_READ_ONLY:
			ptr = SIO_filename[3+driveOffset] + 
					strlen(SIO_filename[3+driveOffset]) - 1;
			while (ptr > SIO_filename[3+driveOffset]) {
				if (*ptr == '/') {
					ptr++;
					break;
					}
				ptr--;
				}
			[d4DiskImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
			[d4DiskImagePowerButton setTitle:@"Off"];
			[d4DiskImageInsertButton setTitle:@"Eject"];
			[d4DiskImageInsertButton setEnabled:YES];
			if (SIO_drive_status[3+driveOffset] == SIO_READ_WRITE) {
				[d4DiskImageProtectButton setTitle:@"Lock"];
				[d4DiskImageLockView setImage:lockoffImage];
				}
			else {
				[d4DiskImageProtectButton setTitle:@"Unlk"];
				[d4DiskImageLockView setImage:lockImage];
				}
			[d4DiskImageProtectButton setEnabled:YES];
			[d4DiskImageView setImage:closed810Image];
			break;
		}

       if (FALSE) /* Legacy SIDE2 check disabled */
       {
           [cartImageRomInsertButton setEnabled:YES];
           [cartImageRomInsertButton setTransparent:NO];
           [cartImageInsertButton setTitle:@"Eject"];
           [cartImageSIDEButton setEnabled:YES];
           [cartImageSIDEButton setTransparent:NO];
           //[cartImageSIDEButton setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
           [cartImageSDXButton setEnabled:YES];
           [cartImageSDXButton setTransparent:NO];
           if (SIDE2_SDX_Mode_Switch)
               [cartImageSDXButton setTitle:@"SDX"];
           else
               [cartImageSDXButton setTitle:@"Load"];
           NSRect r = [cartImageInsertButton frame];
           r.size.width = 48.0;
           [cartImageInsertButton setFrame:r];
           r = [cartImageSecondInsertButton frame];
           r.size.width = 48.0;
           [cartImageSecondInsertButton setFrame:r];
           [cartImageSecondInsertButton setAction:@selector(side2AttachCF:)];
           [cartImageNameField setStringValue:@"SIDE2"];
       } else {
           [cartImageRomInsertButton setEnabled:NO];
           [cartImageRomInsertButton setTransparent:YES];
           [cartImageSIDEButton setEnabled:NO];
           [cartImageSIDEButton setTransparent:YES];
           [cartImageSIDEButton setImage:nil];
           [cartImageSDXButton setEnabled:NO];
           [cartImageSDXButton setTransparent:YES];
           NSRect r = [cartImageInsertButton frame];
           r.size.width = 96.0;
           [cartImageInsertButton setFrame:r];
           r = [cartImageSecondInsertButton frame];
           r.size.width = 96.0;
           [cartImageSecondInsertButton setFrame:r];
           [cartImageSecondInsertButton setAction:@selector(cartSecondStatusChange:)];
       }
           
    if (ULTIMATE_enabled) {
        if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE) {
                [cartImageNameField setStringValue:@"Empty"];
                [cartImageInsertButton setTitle:@"Insert"];
                [cartImageSecondNameField setStringValue:@""];
                [cartImageSecondInsertButton setTransparent:YES];
                [cartImageView setImage:offCartImage];
                }
        else if (FALSE) { /* Legacy SIDE2 check disabled */
            [cartImageSecondNameField setStringValue:@""];
            [cartImageSecondInsertButton setTitle:@"Disk"];
            [cartImageSecondInsertButton setEnabled:YES];
            [cartImageSecondInsertButton setTransparent:NO];
            ptr = side2_compact_flash_filename + strlen(side2_compact_flash_filename) - 1;
            while (ptr > side2_compact_flash_filename) {
                if (*ptr == '/') {
                    ptr++;
                    break;
                    }
                ptr--;
                }
            [cartImageSecondNameField setStringValue:[NSString stringWithCString:ptr encoding:NSASCIIStringEncoding]];
            [cartImageView setImage:onCartImage];
        }
        else {
            ptr = CARTRIDGE_piggyback.filename + strlen(CARTRIDGE_piggyback.filename) - 1;
            while (ptr > CARTRIDGE_piggyback.filename) {
                if (*ptr == '/') {
                    ptr++;
                    break;
                    }
                ptr--;
                }
            [cartImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
            [cartImageInsertButton setTitle:@"Eject"];
            [cartImageView setImage:onCartImage];
            }
    } else {
        if (CARTRIDGE_main.type == CARTRIDGE_NONE) {
                [cartImageNameField setStringValue:@"Empty"];
                [cartImageInsertButton setTitle:@"Insert"];
                [cartImageView setImage:offCartImage];
                }
            else {
                if (strcmp(CARTRIDGE_main.filename,"!Builtin_BASIC_CART!")==0) {
                    [cartImageNameField setStringValue:@"BASIC"];
                } else {
                    ptr = CARTRIDGE_main.filename + strlen(CARTRIDGE_main.filename) - 1;
                    while (ptr > CARTRIDGE_main.filename) {
                        if (*ptr == '/') {
                            ptr++;
                            break;
                            }
                        ptr--;
                        }
                    [cartImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSASCIIStringEncoding]];
                }
                [cartImageInsertButton setTitle:@"Eject"];
                [cartImageView setImage:onCartImage];
                }
            if (CARTRIDGE_main.type == CARTRIDGE_SDX_64 || CARTRIDGE_main.type == CARTRIDGE_SDX_128 ||
                CARTRIDGE_main.type == CARTRIDGE_ATRAX_SDX_64 || CARTRIDGE_main.type == CARTRIDGE_ATRAX_SDX_128 ||
                FALSE) /* Legacy ULTIMATE_1MB check disabled */
                {
                if (CARTRIDGE_piggyback.type == CARTRIDGE_NONE) {
                    [cartImageSecondNameField setStringValue:@""];
                    [cartImageSecondInsertButton setTitle:@"Insert 2"];
                    [cartImageSecondInsertButton setEnabled:YES];
                    [cartImageSecondInsertButton setTransparent:NO];
                    }
                else {
                    ptr = CARTRIDGE_piggyback.filename + strlen(CARTRIDGE_piggyback.filename) - 1;
                    while (ptr > CARTRIDGE_piggyback.filename) {
                        if (*ptr == '/') {
                            ptr++;
                            break;
                            }
                        ptr--;
                        }
                    [cartImageSecondNameField setStringValue:[NSString stringWithCString:ptr encoding:NSASCIIStringEncoding]];
                    [cartImageSecondInsertButton setTitle:@"Eject 2"];
                    [cartImageSecondInsertButton setEnabled:YES];
                    [cartImageSecondInsertButton setTransparent:NO];
                    }
                }
            else
                {
                if (FALSE) { /* Legacy SIDE2 check disabled */
                    [cartImageSecondNameField setStringValue:@""];
                    [cartImageSecondInsertButton setTitle:@"Disk"];
                    [cartImageSecondInsertButton setEnabled:YES];
                    [cartImageSecondInsertButton setTransparent:NO];
                    ptr = side2_compact_flash_filename + strlen(side2_compact_flash_filename) - 1;
                    while (ptr > side2_compact_flash_filename) {
                        if (*ptr == '/') {
                            ptr++;
                            break;
                            }
                        ptr--;
                        }
                    [cartImageSecondNameField setStringValue:[NSString stringWithCString:ptr encoding:NSASCIIStringEncoding]];
                } else {
                    [cartImageSecondNameField setStringValue:@""];
                    [cartImageSecondInsertButton setTitle:@"Insert 2"];
                    [cartImageSecondInsertButton setEnabled:NO];
                    [cartImageSecondInsertButton setTransparent:YES];
                }
            }
    }

    if (CASSETTE_status == CASSETTE_STATUS_NONE) {
			[cassImageNameField setStringValue:@"Empty"];
			[cassImageInsertButton setTitle:@"Insert"];
            [cassImageRecordButton setEnabled:NO];
            [cassImageProtectButton setEnabled:NO];
			[cassImageView setImage:off410Image];
            [cassImageLockView setImage:lockoffImage];
            [cassImageSlider setEnabled:NO];
			[cassImageSlider setIntValue:1];
			[cassImageSliderCurrField setEnabled:NO];
			[cassImageSliderMaxField setStringValue:@""];
			[cassImageSliderCurrField setStringValue:@""];
			[cassImageSliderMaxField setEnabled:NO];
			}
		else {
            int current_block = CASSETTE_GetPosition();
            int max_block = CASSETTE_GetSize();
			ptr = CASSETTE_filename + strlen(CASSETTE_filename) - 1;
			while (ptr > CASSETTE_filename) {
				if (*ptr == '/') {
					ptr++;
					break;
					}
				ptr--;
				}
			[cassImageNameField setStringValue:[NSString stringWithCString:ptr encoding:NSUTF8StringEncoding]];
			[cassImageInsertButton setTitle:@"Eject"];
			[cassImageView setImage:on410Image];
			//printf("In UMSW curr=%d max=%d\n",current_block, max_block);
			[cassImageSliderCurrField setIntValue:current_block];
			[cassImageSliderMaxField  setIntValue:max_block];
			[cassImageSlider setMaxValue:(float)max_block];
			[cassImageSlider setIntValue:current_block];
			[cassImageSlider setEnabled:YES];
			[cassImageSliderCurrField setEnabled:YES];
			[cassImageSliderMaxField setEnabled:YES];
            [cassImageRecordButton setEnabled:YES];
            if (CASSETTE_record)
                [cassImageRecordButton setState:NSOnState];
            else
                [cassImageRecordButton setState:NSOffState];
            [cassImageProtectButton setEnabled:YES];
            if (!CASSETTE_write_protect) {
                [cassImageProtectButton setTitle:@"Lock"];
                [cassImageLockView setImage:lockoffImage];
            }
            else {
                [cassImageProtectButton setTitle:@"Unlock"];
                [cassImageLockView setImage:lockImage];
            }
        }

}

/*------------------------------------------------------------------------------
*  cassSliderChange - Called when the cassette position slider is moved.
*-----------------------------------------------------------------------------*/
- (IBAction)cassSliderChange:(id)sender
{
    CASSETTE_Seek([cassImageSlider intValue]);

    int current_block = CASSETTE_GetPosition();
	[cassImageSliderCurrField setIntValue:current_block];
	[self updateInfo];
}

/*------------------------------------------------------------------------------
*  cassSliderUpdate - Called when the cassette position slider position needs
*     to be updated by program, not user.
*-----------------------------------------------------------------------------*/
- (void)cassSliderUpdate:(int)block
{
    int current_block = CASSETTE_GetPosition();
    int max_block = CASSETTE_GetSize();
    
	[cassImageSliderCurrField setIntValue:current_block];
	[cassImageSliderMaxField  setIntValue:max_block];
	[cassImageSlider setMaxValue:(float)max_block];
	[cassImageSlider setIntValue:current_block];
}

/*------------------------------------------------------------------------------
*  statusLed - Turn the status LED on or off on a drive, different color for
*    read and write.
*-----------------------------------------------------------------------------*/
- (void) statusLed:(int)diskNo:(int)on:(int)read
{
	if (showUpperDrives) {
		if (diskNo < 4)
			return;
		diskNo -= 4;
		}
	else {
		if (diskNo > 3)
			return;
		}
		
	if (on) {
		if (read) {
		    switch(diskNo) {
				case 0:
					[d1DiskImageView setImage:read810Image];
					break;
				case 1:
					[d2DiskImageView setImage:read810Image];
					break;
				case 2:
					[d3DiskImageView setImage:read810Image];
					break;
				case 3:
					[d4DiskImageView setImage:read810Image];
					break;
				}
			}
		else {
		    switch(diskNo) {
				case 0:
					[d1DiskImageView setImage:write810Image];
					break;
				case 1:
					[d2DiskImageView setImage:write810Image];
					break;
				case 2:
					[d3DiskImageView setImage:write810Image];
					break;
				case 3:
					[d4DiskImageView setImage:write810Image];
					break;
				}
			}
		}
	else {
	    switch(diskNo) {
			case 0:
				[d1DiskImageView setImage:closed810Image];
				break;
			case 1:
				[d2DiskImageView setImage:closed810Image];
				break;
			case 2:
				[d3DiskImageView setImage:closed810Image];
				break;
			case 3:
				[d4DiskImageView setImage:closed810Image];
				break;
			}
		}
}

/*------------------------------------------------------------------------------
*  statusLed - Turn the sector number display on a drive on or off.
*-----------------------------------------------------------------------------*/
- (void) sectorLed:(int)diskNo:(int)sectorNo:(int)on
{
	char sectorString[8];
	
	if (showUpperDrives) {
		if (diskNo < 4)
			return;
		diskNo -= 4;
		}
	else {
		if (diskNo > 3)
			return;
		}

	if (on) {
		sprintf(sectorString,"  %03d",sectorNo);
	    switch(diskNo) {
			case 0:
				[d1DiskImageSectorField setStringValue:[NSString stringWithCString:sectorString encoding:NSUTF8StringEncoding]];
				break;
			case 1:
				[d2DiskImageSectorField setStringValue:[NSString stringWithCString:sectorString encoding:NSUTF8StringEncoding]];
				break;
			case 2:
				[d3DiskImageSectorField setStringValue:[NSString stringWithCString:sectorString encoding:NSUTF8StringEncoding]];
				break;
			case 3:
				[d4DiskImageSectorField setStringValue:[NSString stringWithCString:sectorString encoding:NSUTF8StringEncoding]];
				break;
			}
	}
	else {
	    switch(diskNo) {
			case 0:
				[d1DiskImageSectorField setStringValue:@""];
				break;
			case 1:
				[d2DiskImageSectorField setStringValue:@""];
				break;
			case 2:
				[d3DiskImageSectorField setStringValue:@""];
				break;
			case 3:
				[d4DiskImageSectorField setStringValue:@""];
				break;
			}
	}
}

/*------------------------------------------------------------------------------
*  getDiskImageView - Return the image view for a particular drive.
*-----------------------------------------------------------------------------*/
- (NSImageView *) getDiskImageView:(int)tag
{
	switch(tag)
	{
		case 0:
		default:
			return(d1DiskImageView);
		case 1:
			return(d2DiskImageView);
		case 2:
			return(d3DiskImageView);
		case 3:
			return(d4DiskImageView);
	}
}

/*------------------------------------------------------------------------------
*  coldStart - Called when the cold start button in the media status window
*   is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)coldStart:(id)sender
{
	[[ControlManager sharedInstance] coldReset:sender];
}

/*------------------------------------------------------------------------------
*  warmStart - Called when the warm start button in the media status window
*   is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)warmStart:(id)sender;
{
	[[ControlManager sharedInstance] warmReset:sender];
}

/*------------------------------------------------------------------------------
*  limit - Called when the speed limit button in the media status window
*   is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)limit:(id)sender;
{
	[[ControlManager sharedInstance] limit:sender];
}

/*------------------------------------------------------------------------------
*  disableBasic - Called when the disable basic button in the media status 
*   window is pressed.
*-----------------------------------------------------------------------------*/
- (IBAction)disableBasic:(id)sender;
{
    switch (Atari800_machine_type) {
        case Atari800_MACHINE_800:
            [self basicInsert:self];
            break;
        case Atari800_MACHINE_XLXE:
            if (Atari800_builtin_basic)
                [[ControlManager sharedInstance] disableBasic:sender];
            else
                [self basicInsert:self];
            break;
    }
}

/*------------------------------------------------------------------------------
*  setLimitButton - Called to set the speed limit button in the media bar to 
*   a certain state.
*-----------------------------------------------------------------------------*/
- (void)setLimitButton:(int)limit
{
	if (limit) {
		[speedLimitButton setState:NSOnState];
		}
    else {
		[speedLimitButton setState:NSOffState];
		}
}

/*------------------------------------------------------------------------------
*  setDisableBasicButton - Called to set the diable basic button in the media bar to
*   a certain state.
*-----------------------------------------------------------------------------*/
- (void)setDisableBasicButton:(int)mode:(int)onoff
{
    switch(mode) {
        case Atari800_MACHINE_800:
            if (CARTRIDGE_main.type != CARTRIDGE_NONE &&
                (strcmp(CARTRIDGE_main.filename, "!Builtin_BASIC_CART!") == 0)) {
                [disBasicButton setEnabled:NO];
                [disBasicButton setTitle:@""];
                [disBasicButton setState:NSOffState];
                [insertBasicItem setTarget:nil];
            } else {
                [insertBasicItem setTarget:self];
                [disBasicButton setEnabled:YES];
                [disBasicButton setTitle:@"Load Basic"];
                [disBasicButton setState:NSOffState];
            }
            [insertSIDE2Item setTarget:nil];
            break;
        case Atari800_MACHINE_XLXE:
            if (ULTIMATE_enabled) {
               [disBasicButton setEnabled:NO];
               [disBasicButton setTitle:@""];
               [disBasicButton setState:NSOffState];
               [insertBasicItem setTarget:nil];
            } else {
                if (Atari800_builtin_basic) {
                    [insertBasicItem setTarget:self];
                    [disBasicButton setEnabled:YES];
                    if (onoff) {
                        [disBasicButton setTitle:@"Disable Basic"];
                        [disBasicButton setState:NSOnState];
                        }
                    else {
                        [disBasicButton setTitle:@"Disable Basic"];
                        [disBasicButton setState:NSOffState];
                        }
                    [insertSIDE2Item setTarget:self];
                } else {
                    if (CARTRIDGE_main.type != CARTRIDGE_NONE &&
                        (strcmp(CARTRIDGE_main.filename, "BASIC") == 0)) {
                        [disBasicButton setEnabled:NO];
                        [disBasicButton setTitle:@""];
                        [disBasicButton setState:NSOffState];
                        [insertBasicItem setTarget:nil];
                    } else {
                        [insertBasicItem setTarget:self];
                        [disBasicButton setEnabled:YES];
                        [disBasicButton setTitle:@"Load Basic"];
                        [disBasicButton setState:NSOffState];
                    }
                    [insertSIDE2Item setTarget:nil];
                }
            }
            break;
        case Atari800_MACHINE_5200:
            [disBasicButton setEnabled:NO];
            [disBasicButton setTitle:@""];
            [insertBasicItem setTarget:nil];
            break;
    }
}

/*------------------------------------------------------------------------------
*  closeKeyWindow - Called to close the front window in the application.  
*      Placed in this class for lack of a better place. :)
*-----------------------------------------------------------------------------*/
-(void)closeKeyWindow:(id)sender
{
	[[NSApp keyWindow] performClose:NSApp];
}

- (IBAction)machineTypeChange:(id)sender
{
    int index = [sender indexOfSelectedItem];
    if (index > 13)
        requestMachineTypeChange = index + 6;
    else
        requestMachineTypeChange = index + 1;
}

- (IBAction)scaleModeChange:(id)sender
{
    requestScaleModeChange = [sender indexOfSelectedItem] + 1;
}

- (IBAction)widthModeChange:(id)sender
{
    requestWidthModeChange = [sender indexOfSelectedItem] + 1;
}

- (IBAction)artifactModeChange:(id)sender
{
	ANTIC_artif_mode = [sender indexOfSelectedItem];
	requestArtifChange = 1;
}

- (IBAction)checkDisk:(id)sender
{
	if ([sender state] == NSOnState) {
		if (numChecked >= 2) {
			[sender setState:NSOffState];
			}
		else {
			numChecked++;
			}
		checks[[sender tag]] = 1;
		}
	else {
		numChecked--;
		checks[[sender tag]] = 0;
		}
		
	if (numChecked == 2) {
		[self switchDisks];
		}
}

- (void)switchDisks
{
	int i,j;
	int first = 0;
	int second = 0;
	char first_filename[FILENAME_MAX];
	char second_filename[FILENAME_MAX];
	
	for (i=0;i<8;i++) {
		if (checks[i]) {
			first = i;
			break;
			}
		}
	for (j=i+1;j<8;j++) {
		if (checks[j]) {
			second = j;
			break;
			}
		}
	
	strcpy(first_filename, SIO_filename[first]);
	strcpy(second_filename, SIO_filename[second]);
	if (strcmp(first_filename, "None") && strcmp(first_filename, "Off") && strcmp(first_filename, "Empty") ) {
		SIO_Mount(second+1,first_filename,FALSE);
		}
	else {
		SIO_Dismount(second+1);
			}		
	if (strcmp(second_filename, "None") && strcmp(second_filename, "Off") && strcmp(second_filename, "Empty") ) {
		SIO_Mount(first+1,second_filename,FALSE);
		}
	else {
		SIO_Dismount(first+1);
		}
	numChecked = 0;
	for (i=0;i<8;i++)
		checks[i] = 0;
	[d1SwitchButton setState:NSOffState];
	[d2SwitchButton setState:NSOffState];
	[d3SwitchButton setState:NSOffState];
	[d4SwitchButton setState:NSOffState];
	[d5SwitchButton setState:NSOffState];
	[d6SwitchButton setState:NSOffState];
	[d7SwitchButton setState:NSOffState];
	[d8SwitchButton setState:NSOffState];
    [self updateInfo];
}

- (void)enable80ColMode:(int)machineType
{
    switch(machineType) {
        case Atari800_MACHINE_800:
        default:
            [[xep80Pulldown itemAtIndex:1] setTarget:self];
            [[xep80Pulldown itemAtIndex:2] setTarget:self];
            [[xep80Pulldown itemAtIndex:3] setTarget:self];
            [[xep80Pulldown itemAtIndex:4] setTarget:self];
            break;
        case Atari800_MACHINE_XLXE:
            [[xep80Pulldown itemAtIndex:1] setTarget:self];
            [[xep80Pulldown itemAtIndex:2] setTarget:self];
            [[xep80Pulldown itemAtIndex:3] setTarget:nil];
            [[xep80Pulldown itemAtIndex:4] setTarget:nil];
            break;
        case Atari800_MACHINE_5200:
            [[xep80Pulldown itemAtIndex:1] setTarget:nil];
            [[xep80Pulldown itemAtIndex:2] setTarget:nil];
            [[xep80Pulldown itemAtIndex:3] setTarget:nil];
            [[xep80Pulldown itemAtIndex:4] setTarget:nil];
            break;
    }
}

- (void)set80ColMode:(int)xep80Enabled:(int)af80Enabled:(int)bit3Enabled:(int)col80
{
	if (!xep80Enabled && !af80Enabled && !bit3Enabled) {
		[xep80Button setEnabled:NO];
        [xep80Pulldown selectItemAtIndex:0];
		}
	else {
		[xep80Button setEnabled:YES];
		if (col80)
			[xep80Button setState:NSOnState];
		else
			[xep80Button setState:NSOffState];
		}
    if (af80Enabled) {
        [xep80Pulldown selectItemAtIndex:3];
    }
    if (bit3Enabled) {
        [xep80Pulldown selectItemAtIndex:4];
    }
    if (xep80Enabled) {
        if (XEP80_port == 0) {
            [xep80Pulldown selectItemAtIndex:1];
        }
        else {
            [xep80Pulldown selectItemAtIndex:2];
        }
    }
}

- (IBAction)xep80Mode:(id)sender
{
    [[DisplayManager sharedInstance] xep80Mode:sender];
}

-(IBAction)changeXEP80:(id)sender
{
    request80ColChange = 1;
}

- (IBAction)side2SaveRom:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX+1];
    NSString *oldRom = [NSString stringWithCString:side2_rom_filename encoding:NSASCIIStringEncoding];
    
    filename = [self saveFileInDirectory:[oldRom stringByDeletingLastPathComponent]:@"rom"];
            
    if (filename == nil) {
        return;
        }
                
    [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
    
    if (SIDE2_Save_Rom(cfilename) < 0) {
        [self displayError:@"Unable to Save SIDE2 ROM Image!"];
    }
}

- (IBAction)ultimateSaveRom:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX+1];
    NSString *oldRom = [NSString stringWithCString:ultimate_rom_filename encoding:NSASCIIStringEncoding];
    
    filename = [self saveFileInDirectory:[oldRom stringByDeletingLastPathComponent]:@"rom"];

    if (filename == nil) {
        return;
        }
                
    [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
    
    if (ULTIMATE_Save_Rom(cfilename) < 0) {
        [self displayError:@"Unable to Save ULTIMATE ROM Image!"];
    }
}

- (IBAction)side2ChangeRom:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int loaded;
    
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
        loaded = SIDE2_Change_Rom(cfilename, TRUE);
        if (loaded) {
            memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
            Atari_DisplayScreen((UBYTE *) Screen_atari);
            Atari800_Coldstart();
        }
    }
    [self updateInfo];
}

- (IBAction)ultimateChangeRom:(id)sender
{
    NSString *filename;
    char cfilename[FILENAME_MAX];
    int loaded;
    
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_rom_dir encoding:NSUTF8StringEncoding]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
        loaded = ULTIMATE_Change_Rom(cfilename, TRUE);
        if (loaded) {
            memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
            Atari_DisplayScreen((UBYTE *) Screen_atari);
            Atari800_Coldstart();
        }
    }
    [self updateInfo];
}

- (IBAction)side2AttachCF:(id)sender
{
    NSString *filename;
    
    filename = [self browseFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]];
    [self side2AttachCFFile:filename];
}

- (IBAction)side2AttachCFFile:(NSString *)filename
{
    int diskMounted;
    char cfilename[FILENAME_MAX];
    
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX  encoding:NSUTF8StringEncoding];
        strcpy(side2_compact_flash_filename, cfilename);
        if (SIDE2_enabled) {
            diskMounted = SIDE2_Add_Block_Device(cfilename);
            if (!diskMounted)
                [self displayError:@"Unable to Mount Disk Image!"];
        }
    }
    [self updateInfo];
}

- (IBAction)side2RemoveCF:(id)sender
{
    SIDE2_Remove_Block_Device();
    [self updateInfo];
}

- (IBAction)side2SlideSwitch:(id)sender
{
    int changeToValue;
    if ([sender tag] == 2) {
        changeToValue = !SIDE2_SDX_Mode_Switch;
    } else {
        changeToValue = [sender tag];
    }
    SIDE2_SDX_Switch_Change(changeToValue);
    memset(Screen_atari, 0, (Screen_HEIGHT * Screen_WIDTH));
    Atari_DisplayScreen((UBYTE *) Screen_atari);
    Atari800_Coldstart();
    [self updateInfo];
}

- (IBAction)side2Button:(id)sender
{
    SIDE2_Bank_Reset_Button_Change();
}


/*------------------------------------------------------------------------------
*  convertXFDtoATR - This method converts an XFD disk image to an ATR disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertXFDtoATR:(id)sender
{
    NSString *filename;
    FILE *xfd, *atr;
    struct stat fstatus;
    unsigned char buffer[256];
    unsigned short sectors, secSize;
    unsigned short sec;
    unsigned imageSize;
    char cfilename[FILENAME_MAX+1];
    unsigned char hdr[16] = {0};
    int bytes;
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"xfd",@"XFD", nil]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	xfd = fopen(cfilename, "rb");
	if (!xfd) {
            [self displayError:@"Unable to Open .xfd File!"];
            return;
            }

        fstat(fileno(xfd),&fstatus);

        if ( fstatus.st_size == 720*128 )
            {
            sectors = 720;
            secSize = 128;
            }
        else if ( fstatus.st_size == 1040*128 )
            {
            sectors = 1040;
            secSize = 128;
            }
        else if ( fstatus.st_size == 720*256 )
            {
            sectors = 720;
            secSize = 256;
            }
        else
            {
            [self displayError:@"Unrecogized .xfd File Size!"];
            fclose(xfd);
            return;
            }
            
        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"atr"];
                
        if (filename == nil) {
            fclose(xfd);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        atr = fopen(cfilename, "wb");
        if (atr) 
            {
            /* set up the ATR header */
            imageSize = secSize * sectors;
            hdr[1] = (unsigned char)0x02;
            hdr[0] = (unsigned char)0x96;
            hdr[2] = (unsigned char)( (imageSize >> 4) & 255 );
            hdr[3] = (unsigned char)( (imageSize >> 12) & 255 ); 
            hdr[6] = (unsigned char)( imageSize >> 20 );
            hdr[4] = (unsigned char)( secSize & 255 );
            hdr[5] = (unsigned char)( secSize >> 8 );
            bytes = fwrite(hdr, 1, 16, atr);
            if ( bytes != 16 ) {
                [self displayError:@"Error writing new .atr disk image"];
                fclose(xfd);
                fclose(atr);
                unlink(cfilename);
                return;
                }
    
            for(sec = 1; sec <= sectors; sec++)
                {
                bytes = fread(buffer, 1, secSize, xfd);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error reading .xfd disk image"];
                    fclose(atr);
                    fclose(xfd);
                    unlink(cfilename);
                    return;
                    }
                bytes = fwrite(buffer, 1, secSize, atr);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error writing new .atr disk image"];
                    fclose(atr);
                    fclose(xfd);
                    unlink(cfilename);
                    return;
                    }
                }
            fclose(xfd);
            fclose(atr);
            return;
            }
        else
            {
            [self displayError:@"Unable to create new .atr disk image"];
            fclose(xfd);
            return;
            }
        }
    
}

/*------------------------------------------------------------------------------
*  convertATRtoXFD - This method converts an ATR disk image to an XFD disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertATRtoXFD:(id)sender
{
    NSString *filename;
    FILE *xfd, *atr;
    unsigned char buffer[256];
    unsigned short sectors, secSize;
    unsigned short sec;
    unsigned imageSize;
    char cfilename[FILENAME_MAX+1];
    unsigned char hdr[16] = {0};
    int bytes;
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"atr",@"ATR", nil]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	atr = fopen(cfilename, "rb");
	if (!atr) {
            [self displayError:@"Unable to Open .atr File!"];
            return;
            }
            
        bytes = fread(hdr, 1, 16, atr);
        if ( bytes != 16 ) {
            [self displayError:@"Error reading .atr disk image header"];
            fclose(atr);
            return;
            }

        if (hdr[1] != 0x02 || hdr[0] != 0x96) {
            [self displayError2:@"This file is not an ATR file":@"(Invalid Magic in Header)"];
            fclose(atr);
            return;
            }
        
        secSize = hdr[4] + hdr[5]*256;
        imageSize = hdr[2]*16 + hdr[3]*4096 + hdr[6]*1048576;
        sectors = imageSize/secSize;
        
        if ( !((sectors == 720 && secSize == 256) ||
               (sectors == 720 && secSize == 128) ||
               (sectors == 1040 && secSize == 128)) ) {
            [self displayError2:@"Unable to convert to .xfd disk image":@"due to unsupported image size"];
            fclose(atr);
            return;
            }

        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"xfd"];
                
        if (filename == nil) {
            fclose(atr);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        xfd = fopen(cfilename, "wb");

        if ( !xfd ) {
            fclose(atr);
            [self displayError:@"Unable to create new .xfd disk image"];
            return;
            }
        else {
            for(sec = 1; sec <= sectors; sec++)
                {
                bytes = fread(buffer, 1, secSize, atr);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error reading .atr disk image"];
                    fclose(atr);
                    fclose(xfd);
                    unlink(cfilename);
                    return;
                    }
                bytes = fwrite(buffer, 1, secSize, xfd);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error writing new .xfd disk image"];
                    fclose(atr);
                    fclose(xfd);
                    unlink(cfilename);
                    return;
                    }
                }
            fclose(xfd);
            fclose(atr);
            return;
        }
    }
}

/*------------------------------------------------------------------------------
*  convertDCMtoATR - This method converts an DCM disk image to an ATR disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertDCMtoATR:(id)sender
    {
    NSString *filename;
    FILE *atr;
    FILE *dcm;
    char cfilenamein[FILENAME_MAX+1];
    char cfilenameout[FILENAME_MAX+1];
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"dcm",@"DCM", nil]];
    if (filename != nil) {
        [filename getCString:cfilenamein maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	dcm = fopen(cfilenamein, "rb");
	if (!dcm) {
            [self displayError:@"Unable to Open .dcm File!"];
            return;
            }

        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"atr"];
                
        if (filename == nil) {
            fclose(dcm);
            return;
            }
                    
        [filename getCString:cfilenameout maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        atr = fopen(cfilenameout, "wb");
        if (atr) 
            {
            if (!CompFile_DCMtoATR(dcm, atr)) {
                [self displayError:@"Error during image conversion"];
                fclose(atr);
                fclose(dcm);
                unlink(cfilenameout);
                }
            else {
                fflush(atr);
                fclose(atr);
                fclose(dcm);
                }
            return;
            }
        else
            {
            [self displayError:@"Unable to create new .atr disk image"];
            fclose(dcm);
            return;
            }
        }
}




//#define _DCM_DUMP_

#define DCM_CHANGE_BEGIN    0x41		//Change only start of sector  
#define DCM_DOS_SECTOR      0x42		//128 byte compressed sector   
#define DCM_COMPRESSED      0x43		//Uncompressed/compressed pairs
#define DCM_CHANGE_END      0x44		//Change only end of sector    
#define DCM_PASS_END   		0x45		//End of pass
#define DCM_SAME_AS_BEFORE  0x46		//Same as previous non-zero    
#define DCM_UNCOMPRESSED    0x47		//Uncompressed sector          

#define DCM_HEADER_SINGLE	0xFA
#define DCM_HEADER_MULTI	0xF9

#define DCM_DENSITY_SD		0			//Single density, 90K          
#define DCM_DENSITY_DD		1			//Double density, 180K         
#define DCM_DENSITY_ED		2			//Enhanced density, 130K       

typedef unsigned char BYTE;

static int IsBlockEmpty(BYTE *buffer, int size );
static void EncodeRecFA( int bLast, int iPass, int iDensity, int iFirstSec );
static void EncodeRec45(void);
static void EncodeRec46(void);
static void EncodeRec( int bIsFirstSector );
static void EncodeRec41( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, BYTE* pbtSrcOld, int iSrcLen );
static void EncodeRec43( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, int iSrcLen );
static void EncodeRec44( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, BYTE* pbtSrcOld, int iSrcLen );

static BYTE	m_abtCurrBuff[ 0x100 ];
static BYTE	m_abtPrevBuff[ 0x100 ];
static int      m_iSectorSize;
static BYTE*    m_pbtCurr;
static BYTE*    m_pbtPass;
static BYTE*	m_pbtLastRec;

/*------------------------------------------------------------------------------
*  convertATRtoDCM - This method converts an ATR disk image to an DCM disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertATRtoDCM:(id)sender
{
    NSString *filename;
    FILE *dcm, *atr;
    unsigned short sectors, secSize;
    unsigned imageSize;
    char cfilename[FILENAME_MAX+1];
    unsigned char hdr[16] = {0};
    int bytes;
    BYTE* pEnd = m_pbtCurr;
    int bSkip;
    int iFirstSector = 0;
    int iPrevSector = 0;
    int iCurrentSector = 1;
    int iPass = 1;
    int iDensity;
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"atr",@"ATR", nil]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	atr = fopen(cfilename, "rb");
	if (!atr) {
            [self displayError:@"Unable to Open .atr File!"];
            return;
            }
            
        bytes = fread(hdr, 1, 16, atr);
        if ( bytes != 16 ) {
            [self displayError:@"Error reading .atr disk image header"];
            fclose(atr);
            return;
            }

        if (hdr[1] != 0x02 || hdr[0] != 0x96) {
            [self displayError2:@"This file is not an ATR file":@"(Invalid Magic in Header)"];
            fclose(atr);
            return;
            }
        
        secSize = hdr[4] + hdr[5]*256;
        imageSize = hdr[2]*16 + hdr[3]*4096 + hdr[6]*1048576;
        sectors = imageSize/secSize;
        
        if ( !((sectors == 720 && secSize == 256) ||
               (sectors == 720 && secSize == 128) ||
               (sectors == 1040 && secSize == 128)) ) {
            [self displayError2:@"Unable to convert to .dcm disk image":@"due to unsupported image size"];
            fclose(atr);
            return;
            }

        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"dcm"];
                
        if (filename == nil) {
            fclose(atr);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        dcm = fopen(cfilename,"wb");

	if ( !dcm )
	{
            [self displayError:@"Unable to create DCM Image file"];
            fclose(atr);
            return;
	}
        
        m_iSectorSize = secSize;
        
	if ( m_iSectorSize == 0x80 )
	{
 		if ( sectors == 720 )
   			iDensity = DCM_DENSITY_SD;
   		else
   			iDensity = DCM_DENSITY_ED;
	}
	else 
	{
		iDensity = DCM_DENSITY_DD;
	}

	m_pbtPass = (BYTE *) malloc(0x6500);

	memset( m_abtPrevBuff, 0, m_iSectorSize );

	EncodeRecFA( FALSE, iPass, iDensity, iFirstSector );

	//here should be other compression

	while( iCurrentSector <= sectors )
	{
		iFirstSector = 0;

		while( ( m_pbtCurr - m_pbtPass ) < 0x5EFD )
		{
			if ( iCurrentSector > sectors )
				break;

                        fread(m_abtCurrBuff, 1, m_iSectorSize, atr);
			
                        bSkip = IsBlockEmpty( m_abtCurrBuff, m_iSectorSize );

			//first non empty sector is marked as first, what a surprise! :)
			if ( !bSkip && !iFirstSector )
			{
				iFirstSector = iCurrentSector;
				iPrevSector = iCurrentSector;
			}

			//if just skipped, increment sector
			if ( bSkip )
			{
				iCurrentSector++;
			}
			else
			{
				//if there is a gap, write sector number
				if ( ( iCurrentSector - iPrevSector ) > 1 )
				{
					*( m_pbtCurr++ ) = iCurrentSector;
					*( m_pbtCurr++ ) = iCurrentSector >> 8;
				}
				else
				{
					//else mark previous record
					*m_pbtLastRec |= 0x80;
				}

				//first sector could be encoded with only some data
				if ( iCurrentSector == iFirstSector )
					EncodeRec( TRUE );
				else
				{
					//if are same, encode as record 46
					if ( !memcmp( m_abtPrevBuff, m_abtCurrBuff, m_iSectorSize ) )
						EncodeRec46();
					else
						EncodeRec( FALSE );
				}

				//store this sector as previous
				memcpy( m_abtPrevBuff, m_abtCurrBuff, m_iSectorSize );

				//and move pointers
				iPrevSector = iCurrentSector;
				iCurrentSector++;
			}

		}

		//mark previous sector
		*m_pbtLastRec |= 0x80;

		//encode end
		EncodeRec45();

		pEnd = m_pbtCurr;

		//change beginning block
		if ( iCurrentSector > sectors )
			EncodeRecFA( TRUE, iPass, iDensity, iFirstSector );
		else
			EncodeRecFA( FALSE, iPass, iDensity, iFirstSector );

		//and write whole pass

		if ( ( pEnd - m_pbtPass ) > 0x6000 )
		{
                        [self displayError2:@"Unable to convert to .dcm disk image":@"Internal error! Pass too long!"];
			free(m_pbtPass);
			fclose(atr);
                        fclose(dcm);
			unlink( cfilename );
			return;
		}

		if ( fwrite(m_pbtPass, 1, pEnd - m_pbtPass,dcm) != (pEnd - m_pbtPass ) )
		{
                        [self displayError:@"Unable to write to .dcm disk image"];
			free(m_pbtPass);
			fclose(atr);
                        fclose(dcm);
			unlink( cfilename );
			return;
		}

		iPass++;
	}

	fclose(dcm);
	fclose(atr);

	free(m_pbtPass);
    }
}
/*------------------------------------------------------------------------------
*  convertSCPtoATR - This method converts an SCP disk image to an ATR disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertSCPtoATR:(id)sender
{
    NSString *filename;
    FILE *scp, *atr;
    unsigned char buffer[256];
    unsigned short sectors, secSize;
    unsigned short sec;
    unsigned imageSize;
    char cfilename[FILENAME_MAX+1];
    unsigned char hdr[16] = {0};
    unsigned char scphdr[16] = {0};
    int bytes, nowRead;
    BYTE* pMap;
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"scp",@"SCP", nil]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	scp = fopen(cfilename, "rb");
	if (!scp) {
            [self displayError:@"Unable to Open .scp File!"];
            return;
            }
        
        bytes = fread(scphdr, 1, 5, scp);

        if ( scphdr[2] == 128 && scphdr[3] == 40 && scphdr[4] == 18 )
            {
            sectors = 720;
            secSize = 128;
            }
        else if ( scphdr[2] == 128 && scphdr[3] == 40 && scphdr[4] == 26 )
            {
            sectors = 1040;
            secSize = 128;
            }
        else if ( scphdr[2] == 0 && scphdr[3] == 40 && scphdr[4] == 18 )
            {
            sectors = 720;
            secSize = 256;
            }
        else
            {
            [self displayError:@"Unrecogized .scp File Size!"];
            fclose(scp);
            return;
            }
            
        pMap = (BYTE *) malloc(sectors);

        if ( !pMap ) {
            [self displayError2:@"Error allocating memory":@"for sector map!"];
            fclose(scp);
            return;
	    }

        bytes = fread(pMap,1,sectors,scp);
        if ( bytes != sectors )
            {
            [self displayError:@"Error reading .scp disk image"];
            fclose(scp);
            return;
            }
            
        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"atr"];
                
        if (filename == nil) {
            fclose(scp);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        atr = fopen(cfilename, "wb");
        if (atr) 
            {
            /* set up the ATR header */
            imageSize = secSize * sectors;
            hdr[1] = (unsigned char)0x02;
            hdr[0] = (unsigned char)0x96;
            hdr[2] = (unsigned char)( (imageSize >> 4) & 255 );
            hdr[3] = (unsigned char)( (imageSize >> 12) & 255 ); 
            hdr[6] = (unsigned char)( imageSize >> 20 );
            hdr[4] = (unsigned char)( secSize & 255 );
            hdr[5] = (unsigned char)( secSize >> 8 );
            bytes = fwrite(hdr, 1, 16, atr);
            if ( bytes != 16 ) {
                [self displayError:@"Error writing new .atr disk image"];
                fclose(scp);
                fclose(atr);
                unlink(cfilename);
                return;
                }
    
            for(sec = 0; sec < sectors; sec++)
                {
                memset(buffer, 0, secSize);
                if (pMap[sec]) {
                    if ( sec < 3 )
                        nowRead = 0x80;
                    else
                        nowRead = secSize;

                    bytes = fread(buffer, 1, nowRead, scp);
                    if ( bytes != nowRead )
                        {
                        [self displayError:@"Error reading .scp disk image"];
                        fclose(atr);
                        fclose(scp);
                        unlink(cfilename);
                        return;
                        }
                    }
                bytes = fwrite(buffer, 1, secSize, atr);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error writing new .atr disk image"];
                    fclose(atr);
                    fclose(scp);
                    unlink(cfilename);
                    return;
                    }
                }
            fclose(scp);
            fclose(atr);
            return;
            }
        else
            {
            [self displayError:@"Unable to create new .atr disk image"];
            fclose(scp);
            return;
            }
        }
    
}

/*------------------------------------------------------------------------------
*  convertATRtoSCP - This method converts an ATR disk image to an SCP disk
*     image format.
*-----------------------------------------------------------------------------*/
- (IBAction)convertATRtoSCP:(id)sender
{
    NSString *filename;
    FILE *scp, *atr;
    unsigned char buffer[256];
    unsigned short sectors, secSize;
    unsigned short sec;
    unsigned imageSize;
    char cfilename[FILENAME_MAX+1];
    unsigned char hdr[16] = {0};
    unsigned char scphdr[16] = {0};
    int bytes, bytesNow;
    BYTE *pMap;
    
    filename = [self browseFileTypeInDirectory:
                  [NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:[NSArray arrayWithObjects:@"atr",@"ATR", nil]];
    if (filename != nil) {
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
	atr = fopen(cfilename, "rb");
	if (!atr) {
            [self displayError:@"Unable to Open .atr File!"];
            return;
            }
            
        bytes = fread(hdr, 1, 16, atr);
        if ( bytes != 16 ) {
            [self displayError:@"Error reading .atr disk image header"];
            fclose(atr);
            return;
            }

        if (hdr[1] != 0x02 || hdr[0] != 0x96) {
            [self displayError2:@"This file is not an ATR file":@"(Invalid Magic in Header)"];
            fclose(atr);
            return;
            }
        
        secSize = hdr[4] + hdr[5]*256;
        imageSize = hdr[2]*16 + hdr[3]*4096 + hdr[6]*1048576;
        sectors = imageSize/secSize;

        if ( !((sectors == 720 && secSize == 256) ||
               (sectors == 720 && secSize == 128) ||
               (sectors == 1040 && secSize == 128)) ) {
            [self displayError2:@"Unable to convert to .scp disk image":@"due to unsupported image size"];
            fclose(atr);
            return;
            }

        filename = [self saveFileInDirectory:[NSString stringWithCString:atari_disk_dirs[0] encoding:NSUTF8StringEncoding]:@"scp"];
                
        if (filename == nil) {
            fclose(atr);
            return;
            }
                    
        [filename getCString:cfilename maxLength:FILENAME_MAX encoding:NSUTF8StringEncoding];
        scp = fopen(cfilename, "wb");

        if ( !scp ) {
            fclose(atr);
            [self displayError:@"Unable to create new .scp disk image"];
            return;
            }
        else {
            scphdr[0] = 0xFD;
            scphdr[1] = 0xFD;
            if (sectors == 720 && secSize == 256) {
                scphdr[2] = 0;
                scphdr[3] = 40;
                scphdr[4] = 18;
               }
            else if (sectors == 720 && secSize == 128) {
                scphdr[2] = 128;
                scphdr[3] = 40;
                scphdr[4] = 18;
               }
            else {
                scphdr[2] = 128;
                scphdr[3] = 40;
                scphdr[4] = 26;
               }
               
            bytes = fwrite(scphdr, 1, 5, scp);
            if ( bytes != 5 ) {
                [self displayError:@"Error writing new .scp disk image"];
                fclose(scp);
                fclose(atr);
                return;
                }
                
	    pMap = (BYTE *) malloc(sectors);

	    if ( !pMap ) {
                [self displayError2:@"Error allocating memory":@"for sector map!"];
                fclose(scp);
                fclose(atr);
                return;
	        }

	    memset( pMap, 0, sectors );

            fseek( scp, sectors, SEEK_CUR );

            for(sec = 0; sec < sectors; sec++)
                {
                bytes = fread(buffer, 1, secSize, atr);
                if ( bytes != secSize )
                    {
                    [self displayError:@"Error reading .atr disk image"];
                    free(pMap);
                    fclose(atr);
                    fclose(scp);
                    unlink(cfilename);
                    return;
                    }
                    
      		bytesNow = ( sec < 3 ) ? 0x80 : secSize;

       		if ( !IsBlockEmpty( buffer, bytesNow ) ) {
                    pMap[sec] = ( sec % scphdr[4] ) + 1;
                    bytes = fwrite(buffer, 1, secSize, scp);
                    if ( bytes != secSize )
                        {
                        [self displayError:@"Error writing new .scp disk image"];
                        free(pMap);
                        fclose(atr);
                        fclose(scp);
                        unlink(cfilename);
                        return;
                        }
                    }
                }
                
            fseek( scp, 5, SEEK_SET );

            if ( fwrite(pMap,1,sectors,scp) != sectors )
            {
                [self displayError:@"Error writing new .scp disk image"];
                free(pMap);
                fclose(atr);
                fclose(scp);
                unlink(cfilename);
                return;
            }

            free(pMap);
            fflush(scp);
            fclose(scp);
            fclose(atr);
            return;
        }
    }
}

/*------------------------------------------------------------------------------
*  DCM Encode functions
*-----------------------------------------------------------------------------*/

static int IsBlockEmpty(BYTE *buffer, int size )
{
    int i;
    BYTE *ptr = buffer;

    for (i=0;i<size;i++)
        {
        if (*ptr++ != 0) 
            return FALSE;
        }

    return TRUE;
}

void EncodeRecFA( int bLast, int iPass, int iDensity, int iFirstSec )
{
	BYTE btType;
	
        m_pbtCurr = m_pbtPass;
	
	#ifdef _DCM_DUMP_
	printf( "ERFA: %08lX\n", m_pbtCurr - m_pbtPass );
	#endif

	m_pbtLastRec = m_pbtCurr;
        
	btType = bLast ? 0x80 : 0;

	btType |= ( iDensity & 3 ) << 5;

	btType |= ( iPass & 0x1F );

	*( m_pbtCurr++ ) = DCM_HEADER_SINGLE;
	*( m_pbtCurr++ ) = btType;
	*( m_pbtCurr++ ) = iFirstSec;
	*( m_pbtCurr++ ) = iFirstSec >> 8;

}

void EncodeRec45()
{
	#ifdef _DCM_DUMP_
	printf( "ER45: %08lX\n", m_pbtCurr - m_pbtPass );
	#endif

	m_pbtLastRec = m_pbtCurr;
	*( m_pbtCurr++ ) = DCM_PASS_END;
}

void EncodeRec46()
{
	#ifdef _DCM_DUMP_
	printf( "ER46: %08lX\n", m_pbtCurr - m_pbtPass );
	#endif
	
	m_pbtLastRec = m_pbtCurr;
	*( m_pbtCurr++ ) = DCM_SAME_AS_BEFORE;
}

void EncodeRec( int bIsFirstSector )
{
	BYTE abtBuff41[ 0x300 ];
	BYTE abtBuff43[ 0x300 ];
	BYTE abtBuff44[ 0x300 ];
	BYTE* abtBuff47;
	BYTE* pbtBest;
	int iEnd41 = 0x300;
	int iEnd43 = 0x300;
	int iEnd44 = 0x300;

	int iBestMethod = DCM_UNCOMPRESSED;
	int iBestEnd = m_iSectorSize;

	#ifdef _DCM_DUMP_
	printf( "ER: %08lX\n", m_pbtCurr - m_pbtPass );
	#endif
	
	m_pbtLastRec = m_pbtCurr;

	abtBuff47 = m_abtCurrBuff;

	pbtBest = abtBuff47;

	EncodeRec43( abtBuff43, &iEnd43, m_abtCurrBuff, m_iSectorSize );

	if ( !bIsFirstSector )
	{
		EncodeRec41( abtBuff41, &iEnd41, m_abtCurrBuff, m_abtPrevBuff, m_iSectorSize );
		EncodeRec44( abtBuff44, &iEnd44, m_abtCurrBuff, m_abtPrevBuff, m_iSectorSize );
	}

	if ( iEnd41 < iBestEnd )
	{
		iBestMethod = DCM_CHANGE_BEGIN;
		iBestEnd = iEnd41;
		pbtBest = abtBuff41;
	}

	if ( iEnd43 < iBestEnd )
	{
		iBestMethod = DCM_COMPRESSED;
		iBestEnd = iEnd43;
		pbtBest = abtBuff43;
	}

	if ( iEnd44 < iBestEnd )
	{
		iBestMethod = DCM_CHANGE_END;
		iBestEnd = iEnd44;
		pbtBest = abtBuff44;
	}

	*( m_pbtCurr++ ) = iBestMethod;
	memcpy( m_pbtCurr, pbtBest, iBestEnd );
	m_pbtCurr += iBestEnd;
}

void EncodeRec41( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, BYTE* pbtSrcOld, int iSrcLen )
{
	BYTE* pbtS = pbtSrc + iSrcLen - 1;
	BYTE* pbtD = pbtDest;
        int i;

	pbtSrcOld += iSrcLen - 1;

	for(i = 0; i < iSrcLen; i++ )
	{
		if ( *( pbtS-- ) != * ( pbtSrcOld-- ) )
			break;
	}

	pbtS++;

	*( pbtD++ ) = pbtS - pbtSrc;

	int iBytes = pbtS - pbtSrc + 1;

	while( iBytes-- )
	{
		*( pbtD++ ) = *( pbtS-- );
	}

	*piDestLen = pbtD - pbtDest;
}

void EncodeRec43( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, int iSrcLen )
{
	BYTE* pbtEnd = pbtSrc + iSrcLen;
	BYTE* pbtCur = pbtSrc;
	BYTE* pbtD = pbtDest;
        BYTE bt;
        BYTE *p;
        BYTE *pbtNow;

	while( pbtCur < pbtEnd )
	{
		int bFound = FALSE;

		for( pbtNow = pbtCur; pbtNow < ( pbtEnd - 2 ); pbtNow++ )
		{

			if ( ( *pbtNow == *(pbtNow+1) ) && ( *pbtNow == *(pbtNow+2) ) )
			{
				int iUnc = pbtNow - pbtCur;
				
				*( pbtD ++ ) = pbtNow - pbtSrc;
				if ( iUnc )
				{
					memcpy( pbtD, pbtCur, iUnc );
					pbtD += iUnc;
				}

				bt = *pbtNow;
				for( p = pbtNow + 1; p < pbtEnd; p++ )
				{
					if ( *p != bt )
						break;
				}

				if ( p > pbtEnd )
					p = pbtEnd;

				*( pbtD++ ) = p - pbtSrc;
				*( pbtD++ ) = bt;

				pbtCur = p;
				bFound = TRUE;
				break;
			}
		}

		if ( ( pbtCur >= pbtEnd - 2 ) || !bFound ) 
		{
			if ( pbtCur < pbtEnd )
			{
				*( pbtD++ ) = iSrcLen;
				memcpy( pbtD, pbtCur, pbtEnd - pbtCur );
				pbtD += pbtEnd - pbtCur;
			}

			break;
		}

	}

	*piDestLen = pbtD - pbtDest;
}

void EncodeRec44( BYTE* pbtDest, int* piDestLen, BYTE* pbtSrc, BYTE* pbtSrcOld, int iSrcLen )
{
	BYTE* pbtS = pbtSrc;
	BYTE* pbtEnd = pbtSrc + iSrcLen;
	BYTE* pbtD = pbtDest;
        int i;

	for(i = 0; i < iSrcLen; i++ )
	{
		if ( *( pbtS++ ) != * ( pbtSrcOld++ ) )
			break;
	}

	pbtS--;

	*( pbtD++ ) = pbtS - pbtSrc;
	memcpy( pbtD, pbtS, pbtEnd - pbtS );
	pbtD += pbtEnd - pbtS;

	*piDestLen = pbtD - pbtDest;
}


@end
