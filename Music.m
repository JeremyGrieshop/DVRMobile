
#include "Music.h"
#include <MediaPlayer/MPMediaLibrary.h>
#include <MediaPlayer/MPMediaQuery.h>
#include <MediaPlayer/MPMediaItem.h>
#include <MediaPlayer/MPMediaPlaylist.h>

#include <dirent.h>
#include <syslog.h>
#include <unistd.h>

#import <UIKit/UIKit.h>


@class MusicLibrary;
@class MLQuery;
@class MLTrack;


@implementation MusicFileEntry
{
}
@end

@implementation Music

-(NSString*)escapeNonAscii: (NSString*)str
{
  int i = 0, j = 0;
  char buf[256];

  if (str == nil)
    return nil;

  for (i = 0; i < [str length]; i++) {
    unichar c = [str characterAtIndex:i];
    if (c < 255)
      buf[j++] = c;
    else if (c == 8217)
      buf[j++] = '\'';
    else
      buf[j++] = '?';
  }
  buf[j++] = 0;

  return [[NSString alloc] initWithCString:buf];
}

-(NSString*)xmlEncode: (NSString *)str
{
  /* convert all chars <32 and >126 into &#; codes */
  NSMutableString *encodedStr = [[[NSMutableString alloc] init] autorelease];
  int i;
  for (i = 0; i < [str length]; i++) {
    unichar c = [str characterAtIndex: i];
    if (c < 32 || c > 126) {
      [encodedStr appendFormat:@"&#%d;", (int)c];
    } else {
      [encodedStr appendFormat:@"%C", c];
    }
  }

  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];

  return encodedStr;
}

-(NSString*)xmlDecode: (NSString *)str
{
  NSString *decodedStr = str;

  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];

  return decodedStr;
}

-(NSString*)urlEncode: (NSString *)url
{
  NSString *escapedUrl = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  escapedUrl = [escapedUrl stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"]; 

  escapedUrl = [self xmlEncode: escapedUrl];

  return escapedUrl;
}

-(NSString*)urlDecode: (NSString *)url
{
  NSString *decodedUrl = url;

  /* unescape the url % codes */
  decodedUrl = [decodedUrl stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  decodedUrl = [decodedUrl stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  decodedUrl = [decodedUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  /* make sure to preserve XML-encoding */
  decodedUrl = [self xmlEncode: decodedUrl];

  return decodedUrl;
}

-(BOOL)isSupportedType:(NSString*)name
{
  if ([name hasSuffix: @".mp3"] || [name hasSuffix: @".MP3"] ||
      [name hasSuffix: @".mp4"] || [name hasSuffix: @".mp4"] ||
      [name hasSuffix: @".flc"] || [name hasSuffix: @".FLC"] ||
      [name hasSuffix: @".ogg"] || [name hasSuffix: @".OGG"] ||
      [name hasSuffix: @".wma"] || [name hasSuffix: @".WMA"] ||
      [name hasSuffix: @".aac"] || [name hasSuffix: @".AAC"] ||
      [name hasSuffix: @".aif"] || [name hasSuffix: @".AIF"] ||
      [name hasSuffix: @".aiff"] || [name hasSuffix: @".AIFF"] ||
      [name hasSuffix: @".au"] || [name hasSuffix: @".AU"] ||
      [name hasSuffix: @".flac"] || [name hasSuffix: @".FLAC"] ||
      [name hasSuffix: @".wav"] || [name hasSuffix: @".WAV"] ||
      [name hasSuffix: @".m4a"] || [name hasSuffix: @".M4A"]) 
    return YES;
  else
    return NO;
}

-(void)setRootContainer:(NSString*)root
{
  ROOT_CONTAINER        = root;
  _ROOT_CONTAINER       = [@"/" stringByAppendingString:root];
  DOWNLOADS		= [ROOT_CONTAINER stringByAppendingString:@"/Downloads"];
  _DOWNLOADS		= [_ROOT_CONTAINER stringByAppendingString:@"/Downloads"];
  RECORDINGS		= [ROOT_CONTAINER stringByAppendingString:@"/Recordings"];
  _RECORDINGS		= [_ROOT_CONTAINER stringByAppendingString:@"/Recordings"];
  PLAYLISTS             = [ROOT_CONTAINER stringByAppendingString:@"/Playlists"];
  _PLAYLISTS            = [_ROOT_CONTAINER stringByAppendingString:@"/Playlists"];
  ITUNES_PATH		= [root stringByAppendingString: @"/iTunes"];
  ITUNES_ALBUM_PATH     = [ITUNES_PATH stringByAppendingString: @"/Albums"];
  ITUNES_SONG_PATH      = [ITUNES_PATH stringByAppendingString: @"/Songs"];
  ITUNES_ARTIST_PATH    = [ITUNES_PATH stringByAppendingString: @"/Artists"];
  ITUNES_PLAYLIST_PATH  = [ITUNES_PATH stringByAppendingString: @"/Playlists"];
  DOWNLOADS_PATH        = @"/var/mobile/Library/Downloads";
  ITUNES_FS_PATH	= @"/var/mobile/Media//iTunes_Control/Music";
  PLAYLISTS_PATH        = @"/var/mobile/Media/Playlists";
  PWNPLAYER_PATH        = @"/var/mobile/Media/Music/dTunes";
  RECORDINGS_PATH       = @"/var/mobile/Media/Recordings";
}

-(void)setResourceCache: (Cache*)cache
{
  resourceCache = cache;
}

-(void)setSpinningGearView: (CustomSpinningGearView *)view
{
  spinningGear = view;
}

-(void)ReadID3v22Tag: (MusicFileEntry*)entry file:(FILE*)mp3
{
  unsigned char frame_header[6];
  int size;
  
  fread(frame_header, 1, 6, mp3);
  size = (frame_header[3] << 16) | (frame_header[4] << 8) | (frame_header[5]);
 
  while (size > 0) {

    int read = 0;
    if (strncmp("TT2", frame_header, 3) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->title = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TP1", frame_header, 3) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->artist = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TAL", frame_header, 3) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->album = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else {
      /* skip over this frame */
      unsigned char buf[1024];
      while (read < size && read > 0)
        read += fread(buf, 1, (size-read > 1024) ? 1024 : size-read, mp3);
    }

    if (entry->title && entry->artist && entry->album) {
      size = 0;
    } else if (read > 0) {
      fread(frame_header, 1, 6, mp3);
      size = (frame_header[3] << 16) | (frame_header[4] << 8) | (frame_header[5]);
    } else {
      size = 0;
    }
  }
}

-(void)ReadID3v23Tag: (MusicFileEntry*)entry file:(FILE*)mp3 flags:(int)flags
{
  if (flags & 0x40) {
    /* skip over extended header */
    unsigned char extended_header[10];
    fread(extended_header, 1, 10, mp3);
  }

  unsigned char frame_header[10];
  fread(frame_header, 1, 10, mp3);
  
  int size = (frame_header[4] << 24) | (frame_header[5] << 16) |
             (frame_header[6] << 8) | (frame_header[7]);

  while (size > 0) {
    int read = 0;

    if (strncmp("TIT2", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->title = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TPE1", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->artist = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TALB", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->album = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TYER", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->year = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else {
      unsigned char buf[1024];
      while (read < size && read > 0)
        read += fread(buf, 1, (size-read > 1024) ? 1024 : size-read, mp3);
    }
 
    if (entry->title && entry->artist && entry->name && entry->year) {
      size = 0;
    } else if (read > 0) {
      fread(frame_header, 1, 10, mp3);
      size = (frame_header[4] << 24) | (frame_header[5] << 16) |
                 (frame_header[6] << 8) | (frame_header[7]); 
    } else {
      size = 0;
    }
  }
}

-(void)ReadID3v24Tag: (MusicFileEntry*)entry file:(FILE*)mp3 flags:(int)flags
{
  if (flags & 0x40) {
    /* skip over extended header */
    unsigned char extended_header[5];
    fread(extended_header, 1, 5, mp3);

    /* extract number of flags in extended header */
    int num_flags = extended_header[4];

    int i;
    for (i = 0; i < num_flags; i++) {
      fread(extended_header, 1, 1, mp3);
    }
  }

  unsigned char frame_header[10];
  fread(frame_header, 1, 10, mp3);

  int size = (frame_header[4] << 24) | (frame_header[5] << 16) |
             (frame_header[6] << 8) | (frame_header[7]);

  while (size > 0) {
    int read = 0;

    if (strncmp("TIT2", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->title = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TPE1", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->artist = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else if (strncmp("TALB", frame_header, 4) == 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);

      entry->album = [[[NSString alloc] initWithCString: (frame+1)] autorelease];
      free(frame);
    } else {
      unsigned char buf[1024];
      while (read < size && read > 0)
        read += fread(buf, 1, (size-read > 1024) ? 1024 : size-read, mp3);
    }

    if (entry->title && entry->artist && entry->name && entry->year) {
      size = 0;
    } else if (read > 0) {
      fread(frame_header, 1, 10, mp3);
      size = (frame_header[4] << 24) | (frame_header[5] << 16) |
                 (frame_header[6] << 8) | (frame_header[7]);
    } else {
      size = 0;
    }
  }
}

-(void)ReadID3Tag: (MusicFileEntry*)entry
{
  if (entry->path) {
    FILE *mp3 = fopen([entry->path UTF8String], "rb");
    if (mp3) {
      unsigned char header[10];
    
      /* read the first 10 bytes for the ID3v2 header */ 
      int read = fread(header, 1, 10, mp3);
      if (strncmp("ID3", header, 3)) {
        /* this is not an ID3v2 tag */
        fclose(mp3);
        return;
      }

      /* extract the version */
      int verMajor = header[3];
      int verMinor = header[4];

      /* extract the flags field */
      int flags = header[5];

      if (verMajor == 2) {
        /* version 2.2 */
        [self ReadID3v22Tag: entry file:mp3];
      } else if (verMajor == 3) {
        /* version 2.3 */
        [self ReadID3v23Tag: entry file:mp3 flags:flags];
      } else if (verMajor == 4) {
        /* version 2.4 */
        [self ReadID3v24Tag: entry file:mp3 flags:flags];
      }
       
      fclose(mp3);
    } 
  }
}

-(void)LoadMusicEntries
{
  MusicLibrary *ml;
  MLQuery *query;
  MusicFileEntry *entry;

  syslog(LOG_INFO, "Loading music entries..");

  trackEntries = [[[NSMutableArray alloc] initWithCapacity:50] autorelease];
  albumEntries = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
  artistEntries = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];

  ml = [MusicLibrary sharedMusicLibrary];
  query = [[[MLQuery alloc] init] autorelease];

  [spinningGear setText: @"Loading iTunes Tracks"];

  int i;
  for (i = 0; i < [query countOfEntities]; i++) {
    MLTrack *track = [query entityAtIndex: i];
    if (track == nil)
      continue;

    /* we have a good track */
    entry = [[MusicFileEntry alloc] autorelease];
    entry->name = [[[NSString alloc] initWithString: [track title]] autorelease];
    entry->title = entry->name;
    if ([track album])
      entry->album = [[[NSString alloc] initWithString: [track album]] autorelease];
    else
      syslog(LOG_DEBUG, "Title %s has no album", [entry->name UTF8String]);
    if ([track artist])
      entry->artist = [[[NSString alloc] initWithString: [track artist]] autorelease];
    else
      syslog(LOG_DEBUG, "Title %s has no artist", [entry->name UTF8String]);
    if ([track path])
      entry->path = [[[NSString alloc] initWithString: [track path]] autorelease];
    else
      syslog(LOG_DEBUG, "Title %s has no path", [entry->name UTF8String]);
    entry->genre = nil;
    entry->duration = [track durationInMS];
    entry->type = 1;

    if ([entry->artist length] > 0) {
      /* first determine if the artist already has an entry listed */
      int j = 0;
      BOOL foundArtist = NO;
      for (j = 0; j < [artistEntries count] && !foundArtist; j++) {
        MusicFileEntry *artistEntry = [artistEntries objectAtIndex:j];
        if ([artistEntry->name isEqualToString: entry->artist]) {
          /* we found a matching artist, update album, if necessary */
          int k = 0;
          if ([entry->album length] > 0) {
            BOOL foundAlbum = NO;
            for (k = 0; k < [artistEntry->albumEntries count] && !foundAlbum; k++) {
              MusicFileEntry *albumEntry = [artistEntry->albumEntries objectAtIndex:k];
              if ([albumEntry->name isEqualToString: entry->album]) {
                /* found a matching album, update it's track list */
                [albumEntry->trackEntries addObject: entry];
                foundAlbum = YES;
              }
            }

            if (!foundAlbum) {
              /* update this artists album list */
              MusicFileEntry *albumEntry = [[MusicFileEntry alloc] autorelease];
              albumEntry->name = entry->album;
              albumEntry->type = 0;

              /* add this track to the new album */
              albumEntry->trackEntries = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
              [albumEntry->trackEntries addObject: entry];

              /* add this album to the artist */
              [artistEntry->albumEntries addObject: albumEntry];

              /* insert it alphabetically */
              int l;
              for (l = 0; l < [albumEntries count]; l++) {
                MusicFileEntry *e = [albumEntries objectAtIndex: l];
                if ([e->name compare: albumEntry->name] == NSOrderedDescending)
                  break;
              }
              [albumEntries insertObject: albumEntry atIndex: l];
            }
          }

          /* update the track list for this artist */
          [artistEntry->trackEntries addObject: entry];
 
          /* discontinue the search */
          foundArtist = YES;
        }
      }

      if (!foundArtist) {
        /* we have a new artist, add it to the list */
        MusicFileEntry *artistEntry = [[MusicFileEntry alloc] autorelease];
        artistEntry->name = entry->artist;
        artistEntry->type = 0;
        [artistEntries addObject: artistEntry];
        artistEntry->albumEntries = [[[NSMutableArray alloc] initWithCapacity:5] autorelease];

        /* add this album */
        if ([entry->album length] > 0) {
          /* first make sure we haven't already added this album (soundtracks) */
          BOOL albumExists = NO;
          for (j = 0; j < [albumEntries count]; j++) {
            MusicFileEntry *albumEntry = [albumEntries objectAtIndex:j];
            if ([albumEntry->name isEqualToString: entry->album]) {
              [albumEntry->trackEntries addObject: entry];
              [artistEntry->albumEntries addObject: albumEntry];
              albumExists = YES;
            }
          }

          MusicFileEntry *albumEntry = nil;
          if (!albumExists) {
            albumEntry = [[MusicFileEntry alloc] autorelease];
            albumEntry->name = entry->album;
            albumEntry->type = 0;
            albumEntry->trackEntries = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
            [albumEntry->trackEntries addObject: entry];
            [albumEntries addObject: albumEntry];
            [artistEntry->albumEntries addObject: albumEntry];
          }
        }

        artistEntry->trackEntries = [[[NSMutableArray alloc] initWithCapacity:30] autorelease];
        [artistEntry->trackEntries addObject: entry];
      }
    }

    /* always add a new track, alphabetically */
    int j;
    for (j = 0; j < [trackEntries count]; j++) {
      MusicFileEntry *e = [trackEntries objectAtIndex: j];
      if ([e->title compare: entry->title] == NSOrderedDescending)
        break;
    }
    [trackEntries insertObject: entry atIndex: j];
  }

  /* log some messages */
  syslog(LOG_INFO, "Music LoadEntries loaded %d Artists.", [artistEntries count]);
  syslog(LOG_INFO, "Music LoadEntries loaded %d Albums.", [albumEntries count]);
  syslog(LOG_INFO, "Music LoadEntries loaded %d Songs.", [trackEntries count]);

  [spinningGear setText: @"Loading Download Tracks"];

  /* now load Downloads */
  downloadEntries = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
  allDownloadEntries = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
  [self ListDownloadsInternal: DOWNLOADS_PATH withArray:downloadEntries];

  syslog(LOG_INFO, "Music LoadEntries loaded %d downloads.", [downloadEntries count]);

  [spinningGear setText: @"Loading Playlists"];

  /* load Playlists, if they're available */
  playlistsEntries = [[[NSMutableArray alloc] initWithCapacity:5] autorelease];
  [self ListPlaylistsInternal: PLAYLISTS_PATH withArray: playlistsEntries];

  syslog(LOG_INFO, "Music LoadEntries loaded %d playlists.", [playlistsEntries count]);
}

-(BOOL)isMusicFilePrefix:(NSString*)path
{
  NSString *realPath = [path stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  syslog(LOG_DEBUG, "isMusicFilePrefix: %s", [realPath UTF8String]);

  if ([realPath hasPrefix: _ROOT_CONTAINER])
    return YES;
  else if ([realPath hasPrefix: ROOT_CONTAINER])
    return YES;
  else if ([realPath hasPrefix: ITUNES_FS_PATH])
    return YES;

  return [self isSupportedType: realPath];
}

-(void)SendFile: (NSString *)symbolicPath httpDelegate:(id)delegate
{
  char tmp[256];

  syslog(LOG_DEBUG, "Music SendFile for file = %s", [symbolicPath UTF8String]);

  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSString *path = [self TranslateSymbolicPath:symbolicPath];
  FILE *f = fopen([path UTF8String], "r");
  if (!f) {
    syslog(LOG_ERR, "Unable to open file [%s]", [path UTF8String]);
    return;
  }

  [delegate WriteString: "HTTP/1.0 200 OK\r\n" ];
  [delegate WriteString: "Server: DVRMobile/1.0\r\n" ];

  NSDate *today = [NSDate date];
  sprintf(tmp, "Date: %s\r\n", [[today description] UTF8String]);
  [delegate WriteString: tmp ];

  fseek(f, 0, SEEK_END);
  int fileSize = ftell(f);
  rewind(f);

  sprintf(tmp, "Content-Length: %d\r\n", fileSize);
  [delegate WriteString: tmp ];
  [delegate WriteString: "Content-Type: audio/mpeg\r\n" ];
  [delegate WriteString: "Connection: close\r\n" ];
  [delegate WriteString: "\r\n" ];

  syslog(LOG_DEBUG, "Music request sending file..");

  if ([[path UTF8String] hasSuffix: @".mp3"]) {
    char buf[4096];
    BOOL ok = YES;
    while (!feof(f) && ok) {
      int bytes = fread(buf, 1, 4096, f);
      if (bytes > 0) {
        ok = [delegate WriteData: buf size:bytes];
        syslog(LOG_DEBUG, "Music SendFile wrote %d bytes", bytes);
      }
    }
  } else {
    fclose(f);

    /* need ffmpeg to transcode */
    size_t bytesRead = 0;
    NSString *ffmpegCmd = @"/var/root/bin/ffmpeg -i ";
    ffmpegCmd = [ffmpegCmd stringByAppendingString: path];
    ffmpegCmd = [ffmpegCmd stringByAppendingString: @" -ab 320k -ar 44100 -"];

    FILE *output = popen([ffmpegCmd UTF8String], "r");
    if (output) {
      char buf[4096];
      memset(buf, 0, 4096);
      BOOL ok = YES;
      while (!feof(output) && ok) {
        int bytes = fread(buf, 1, 4096, output);
        if (bytes > 0) {
          ok = [delegate WriteData: buf size: bytes];
          syslog(LOG_DEBUG, "Music SendFile wrote %d (transcoded) bytes", bytes);
        }
      }

      pclose(output);
    }
  }

  fclose(f);

  syslog(LOG_DEBUG, "Music SendFile request ended.");
}

-(void)QueryItem: (NSString *)url
{

}

/*
 * Translates:
 *    "Downloads" to "/var/mobile/Downloads/"
 *    "Playlists" to "/var/mobile/Library/Playlists/"
 */
-(NSString*)TranslateSymbolicPath: (NSString *)symbolicPath
{
  NSString *realPath = symbolicPath;

  if (realPath == nil)
    return nil;

  /* unescape the url % codes */
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:_DOWNLOADS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString: _DOWNLOADS
                    withString:DOWNLOADS_PATH options:0 range:range];
  }

  range = [realPath rangeOfString:DOWNLOADS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString:DOWNLOADS withString:DOWNLOADS_PATH];
  }


  range = [realPath rangeOfString:_RECORDINGS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString: _RECORDINGS
                    withString:RECORDINGS_PATH options:0 range:range];
  }

  range = [realPath rangeOfString:RECORDINGS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString:RECORDINGS withString:RECORDINGS_PATH];
  }


  range = [realPath rangeOfString:_PLAYLISTS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString: _PLAYLISTS
                    withString:PLAYLISTS_PATH options:0 range:range];
  }

  range = [realPath rangeOfString:PLAYLISTS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString: PLAYLISTS
                    withString:PLAYLISTS_PATH options:0 range:range];
  }

  return realPath;
}

-(void)ListMusic:(NSString*)path recursive:(BOOL)recurse withArray:(NSMutableArray*)list
{

  MusicFileEntry *entry = [[MusicFileEntry alloc] autorelease];
  entry->name = @"iTunes";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
    [self ListITunes: ITUNES_PATH recursive:recurse withArray:list];
  }

  entry = [[MusicFileEntry alloc] autorelease];
  entry->name = @"Downloads";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
    NSMutableArray *downloadList;
    downloadList = [self ListDownloads: DOWNLOADS_PATH recursive:recurse];
    int i = 0;
    for (i = 0; i < [downloadList count]; i++)
      [list addObject: [downloadList objectAtIndex:i]];
  }

  if ([playlistsEntries count] > 0) {
    entry = [[MusicFileEntry alloc] autorelease];
    entry->name = @"Playlists";
    entry->type = 0;
    entry->path = nil;
    [list addObject: entry];

    if (recurse) {
      int i = 0;
      for (i = 0; i < [playlistsEntries count]; i++)
        [list addObject: [playlistsEntries objectAtIndex:i]];
    }
  }
}

-(void)ListITunes: (NSString*)path recursive:(BOOL)recurse withArray:(NSMutableArray*)list
{
  MusicFileEntry *entry;

  if ([path hasPrefix: ITUNES_PLAYLIST_PATH]) {
    /* not sure what to do yet... */
  } else if ([path hasPrefix: ITUNES_ARTIST_PATH]) {
    int i;
    BOOL found = NO;
    for (i = 0; i < [artistEntries count] && !found; i++) {
      entry = [artistEntries objectAtIndex:i];
      if ([path isEqualToString: ITUNES_ARTIST_PATH]) {
        /* list them all */
        [list addObject: entry];
      } else {
        if ([path hasSuffix: entry->name]) {
          /* we're only interested in this artist's tracks */
          int j;
          for (j = 0; j < [entry->trackEntries count]; j++) {
            [list addObject: [entry->trackEntries objectAtIndex:j]];
          }

          found = YES;
        }
      }
    }
  } else if ([path hasPrefix: ITUNES_ALBUM_PATH]) {
    int i;
    BOOL found = NO;
    for (i = 0; i < [albumEntries count] && !found; i++) {
      entry = [albumEntries objectAtIndex:i];
      if ([path isEqualToString: ITUNES_ALBUM_PATH]) {
        /* list them all */
        [list addObject: entry];
      } else {
        if ([path hasSuffix: entry->name]) {
          /* we're only interested in this album's tracks */
          int j;
          for (j = 0; j < [entry->trackEntries count]; j++) {
            [list addObject: [entry->trackEntries objectAtIndex:j]];
          }

          found = YES;
        }
      }
    }
  } else if ([path hasPrefix: ITUNES_SONG_PATH]) {
    int i;
    for (i = 0; i < [trackEntries count]; i++) {
      entry = [trackEntries objectAtIndex:i];
      [list addObject: entry];
    }
  } else if ([path hasPrefix: ITUNES_PATH]) {
    entry = [[MusicFileEntry alloc] autorelease];
    entry->type = 0;
    entry->name = @"Artists";
    entry->path = nil;
    [list addObject: entry]; 

    if (recurse) {
      [self ListITunes: ITUNES_ARTIST_PATH recursive:recurse withArray:list];
    }

    entry = [[MusicFileEntry alloc] autorelease];
    entry->type = 0;
    entry->name = @"Albums";
    entry->path = nil;
    [list addObject: entry]; 

    if (recurse) {
      [self ListITunes: ITUNES_ALBUM_PATH recursive:recurse withArray:list];
    }

    entry = [[MusicFileEntry alloc] autorelease];
    entry->type = 0;
    entry->name = @"Songs";
    entry->path = nil;
    [list addObject: entry]; 

    if (recurse) {
      [self ListITunes: ITUNES_SONG_PATH recursive:recurse withArray:list];
    }
  }
}

-(void)ListPlaylistsInternal: (NSString*)path withArray:(NSMutableArray*)list
{
  DIR *dir;
  char buf[512];
  struct dirent *dirp;
  int type;

  /* try reading iTunes playlists first */
  MPMediaLibrary *mLib = [MPMediaLibrary defaultMediaLibrary];
  if (mLib) {
    MPMediaQuery *mQuery = [MPMediaQuery playlistsQuery];
    if (mQuery) {
      NSArray *playlists = [mQuery collections];
      for (MPMediaItem *pl in playlists) {
        NSString *name = [[[NSString alloc] initWithString: 
             [pl valueForProperty: MPMediaPlaylistPropertyName]] autorelease];
        name = [self escapeNonAscii: name];

        MusicFileEntry *entry = [[MusicFileEntry alloc] autorelease];
        entry->name = name;
        entry->type = 2;
        entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];
        entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];       

        NSArray *songs = [pl items];
        for (MPMediaItem *song in songs) {
          NSString *trackName = [song valueForProperty: MPMediaItemPropertyTitle];
          /* run through our tracks to find it in our path */
          int i;
          for (i = 0; i < [trackEntries count]; i++) {
            MusicFileEntry *trackEntry = [trackEntries objectAtIndex: i];
            if ([trackEntry->name isEqualToString: trackName]) {
              [entry->children addObject: trackEntry];
            }
          }
        }

        [list addObject: entry];
      }
    }
  }

  sprintf(buf, "%s", [path UTF8String]);
  if ((dir = opendir(buf)) == NULL) {
    syslog(LOG_ERR, "LoadDirectory: unable to open directory %s", buf);
    return;
  }

  /* begin reading the directory */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *name = [NSString stringWithCString: dirp->d_name];
    /* skip the hidden . dirs */
    if ([name hasPrefix:@"."])
      continue;

    /* skip any directories */
    if (dirp->d_type == DT_DIR)
      continue;

    MusicFileEntry *entry = [[MusicFileEntry alloc] autorelease];
    entry->name = name;
    entry->type = 2;
    entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];
    entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];

    /* load each track in this playlist */
    FILE *playlist = fopen([entry->path UTF8String], "r");
    if (playlist) {
      char buffer[256];
      while (!feof(playlist)) {
        MusicFileEntry *childEntry = [[MusicFileEntry alloc] autorelease];
        childEntry->type = 1;

        memset(buffer, 0, 256);
        fgets(buffer, 256, playlist);
        buffer[strlen(buffer)-1] = '\0';
        childEntry->path = [[[NSString alloc] initWithCString: buffer] autorelease];
        childEntry->path = [self TranslateSymbolicPath: childEntry->path];
        
        memset(buffer, 0, 256);
        fgets(buffer, 256, playlist);
        buffer[strlen(buffer)-1] = '\0';
        childEntry->artist = [[[NSString alloc] initWithCString: buffer] autorelease];

        memset(buffer, 0, 256);
        fgets(buffer, 256, playlist);
        buffer[strlen(buffer)-1] = '\0';
        childEntry->title = [[[NSString alloc] initWithCString: buffer] autorelease];
        childEntry->name = childEntry->title;

        memset(buffer, 0, 256);
        fgets(buffer, 256, playlist);
        buffer[strlen(buffer)-1] = '\0';
        childEntry->album = [[[NSString alloc] initWithCString: buffer] autorelease];

        fgets(buffer, 256, playlist);
        fgets(buffer, 256, playlist);

        [entry->children addObject: childEntry];
      }
      fclose(playlist);
    }

    [list addObject: entry];
  }
}

-(void)ListDownloadsInternal: (NSString*)path withArray:(NSMutableArray*)list
{
  DIR *dir;
  char buf[512];
  struct dirent *dirp;
  int type;

  sprintf(buf, "%s", [path UTF8String]);    
  if ((dir = opendir(buf)) == NULL) {
    syslog(LOG_ERR, "LoadDirectory: unable to open directory %s", buf);
    return;    
  }

  /* begin reading the directory */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *name = [NSString stringWithCString: dirp->d_name];
    /* skip the hidden . dirs */
    if ([name hasPrefix:@"."])
      continue;

    /* for now only look for audio files */
    if ((dirp->d_type != DT_DIR) && ![self isSupportedType: dirp->d_name])
      continue;

    if (dirp->d_type == DT_DIR)
      type = 0;
    else
      type = 1;

    MusicFileEntry *entry = [[MusicFileEntry alloc] autorelease];
    entry->name = name;
    entry->type = type;
    entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];

    /* extract song/artist/album from the .mp3 */
    entry->title = entry->album = entry->artist = nil; 
    if ([name hasSuffix:@".MP3"] || [name hasSuffix:@".mp3"])
      [self ReadID3Tag: entry];

    [list addObject: entry];
    [allDownloadEntries addObject: entry];

    if (type == 0) {
      NSString *newPath = [path stringByAppendingString:@"/"];
      newPath = [newPath stringByAppendingString:name];
 
      entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
      [self ListDownloadsInternal: newPath withArray: entry->children];
    }
  }

  closedir(dir);
}

-(NSMutableArray *) ListPlaylists: (NSString*)path recursive:(BOOL)recurse
{
  if ([path isEqualToString: PLAYLISTS_PATH])
    return playlistsEntries;

  int i;
  for (i = 0; i < [playlistsEntries count]; i++) {
    MusicFileEntry *entry = [playlistsEntries objectAtIndex:i];
    NSString *name = entry->name;

    NSRange range = [path rangeOfString: name];
    if (range.location != NSNotFound) {
      /* load this playlist */
      return entry->children;
    }
  }
}

-(NSMutableArray *) ListDownloads: (NSString*)path recursive:(BOOL)recurse
{
  NSString *name;
  MusicFileEntry *entry;

  if ([path isEqualToString: DOWNLOADS_PATH] && recurse) {
    return allDownloadEntries;
  } else if ([path isEqualToString: DOWNLOADS_PATH]) {
    return downloadEntries;
  }

  int i;
  for (i = 0; i < [allDownloadEntries count]; i++) {
    entry = [allDownloadEntries objectAtIndex:i];
    name = entry->name;

    NSRange range = [path rangeOfString: name];
    if (range.location != NSNotFound) {
      return entry->children;
    }
  }

  return nil;
}

-(NSMutableArray *) ListRecordings
{
  return recordingEntries;
}

-(NSMutableArray *)Shuffle: (NSMutableArray*)list withSeed:(int)seed withStart:(NSString*)start
{
  NSMutableArray *shuffle = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
  NSMutableArray *temp = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];

  int i = 0;
  for (i = 0; i < [list count]; i++) {
    MusicFileEntry *entry = [list objectAtIndex: i];
    [temp addObject: entry]; 
  }

  srand(seed);

  i = random() % [list count];
  while ([temp count] > 0) {
    MusicFileEntry *entry = [temp objectAtIndex: i];
    [temp removeObjectAtIndex: i];

    if ([entry->path isEqualToString: start])
      [shuffle insertObject: entry atIndex:0];
    else
      [shuffle addObject: entry]; 

    i = random() % [temp count];
  }

  return shuffle;
}

-(void)QueryContainer: (NSString*)symbolicPath itemCount:(int)itemCount
         anchorItem:(NSString*)anchor anchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder 
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate
{
  char tmp[512];
  syslog(LOG_DEBUG, "Music QueryContainer: %s", [symbolicPath UTF8String]);

  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:ROOT_CONTAINER];
  if (range.location == NSNotFound) {
    syslog(LOG_ERR, "QueryContainer, invalid path!");
    return;
  }

  NSString *path = [self TranslateSymbolicPath: symbolicPath];
  syslog(LOG_DEBUG, "Music QueryContainer, path = %s", [path UTF8String]);

  NSString *anchorItem = nil;
  if (anchor != nil) {
    syslog(LOG_DEBUG, "QueryContainer, anchor = %s", [anchor UTF8String]);

    NSString *realAnchor = [anchor  stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
    realAnchor = [realAnchor stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
    realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
    realAnchor = [realAnchor stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    /* if it's a file anchor, we'll find the anchorItem of the form _ROOT_CONTAINER/path/.. */
    NSRange range2 = [realAnchor rangeOfString:_ROOT_CONTAINER];
    if (range2.location == NSNotFound) {
      /* otherwise, we'll get an anchorItem:  /TiVoConnect?Command=QueryContainer&Container=.. */
      anchorItem = [realAnchor
        stringByReplacingOccurrencesOfString:@"/TiVoConnect?Command=QueryContainer&Container="
        withString:@""];
      /* replace "ROOT_CONTAINER" with "/var/mobile/Media/Downloads" */
      anchorItem = [self TranslateSymbolicPath: anchorItem];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem = %s", [anchorItem UTF8String]);
    } else {
      /* replace "_ROOT_CONTAINER" with "/var/mobile/Media/DCIM" */
      anchorItem = [self TranslateSymbolicPath: anchor];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem = %s", [anchorItem UTF8String]);
    }
  }

  /* list the container */
  NSMutableArray *list = nil;
  if ([path hasPrefix: DOWNLOADS_PATH]) {
    /* list the file entries inside downloads */
    list = [self ListDownloads:path recursive:recurse];
  } else if ([path hasPrefix: RECORDINGS_PATH]) {
    list = [self ListRecordings];
  } else if ([path hasPrefix: PLAYLISTS_PATH]) {
    list = [self ListPlaylists:path recursive:recurse];
  } else if ([path isEqualToString: ROOT_CONTAINER]) {
    /* list all file entries (downloads + itunes) */
    list = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
    [self ListMusic:path recursive:recurse withArray:list];
  } else {
    /* list the itunes entries */
    list = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
    [self ListITunes:path recursive:recurse withArray:list];
  }

  /* apply a filter, if it exists */
  NSMutableArray *filterList;
  if ([filter isEqualToString: @"audio%2F*"]) {
    filterList = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
    int i = 0;
    for (i = 0; i < [list count]; i++) {
      MusicFileEntry *entry = [list objectAtIndex:i];
      if (entry->type == 0)
        continue;

      [filterList addObject: entry];
    }

    list = filterList;
  }

  /* shuffle, if necessary */
  if ([sortOrder isEqualToString: @"Random"]) {
    list = [self Shuffle: list withSeed:randomSeed withStart:randomStart];
  }

  [delegate WriteString: "HTTP/1.0 200 OK\r\n" ];
  [delegate WriteString: "Server: DVRMobile/1.0\r\n" ];
 
  NSDate *today = [NSDate date];
  sprintf(tmp, "Date: %s\r\n", [[today description] UTF8String]);
  [delegate WriteString: tmp ];

  [delegate WriteString: "Content-Type: text/xml\r\n" ];
  [delegate WriteString: "Connection: close\r\n" ];
  [delegate WriteString: "\r\n" ];

  int i = 0;
  BOOL foundAnchor = NO;
  /* determine if the query contains an AnchorItem */
  if (nil != anchorItem) {
    /* skip through the list to find our anchor */
    for (i = 0; (i < [list count]) && !foundAnchor; i++) {
      MusicFileEntry *item = [list objectAtIndex:i];
      if (item->path != nil) {
        /* file anchor */
        if ([[@"/" stringByAppendingString: item->path] isEqualToString: anchorItem])
          foundAnchor = YES;
        if ([item->path isEqualToString: anchorItem])
          foundAnchor = YES;
      } else {
        /* folder anchor */
        if ([anchorItem isEqualToString: DOWNLOADS_PATH] && [item->name isEqualToString: @"Downloads"])
          foundAnchor = YES;
        if ([anchorItem isEqualToString: PLAYLISTS_PATH] && [item->name isEqualToString: @"Playlists"])
          foundAnchor = YES;

        NSString *url = [path stringByAppendingString:@"/"];
        url = [url stringByAppendingString:item->name];

        if ([url isEqualToString: anchorItem])
          foundAnchor = YES;

        if ([url hasPrefix: ROOT_CONTAINER])
          url = [@"/" stringByAppendingString: url];

        if ([url isEqualToString: anchorItem])
          foundAnchor = YES;
      }
    }
  }

  if (anchor && !foundAnchor) {
    syslog(LOG_ERR, "Unable to find anchor!  %s", [anchorItem UTF8String]);
  }

  if (itemCount < 0) {
    /* we're walking backwards from the anchor, use absolute value for item count */
    i = (i + itemCount < 0) ? 0 : (i + itemCount);
    itemCount = -1 * itemCount; 
  } else {
    if (foundAnchor)
      i += anchorOffset;
    if (i < 0)
      i = 0;
  }

  /* if unspecified, let itemCount return all items */
  if (itemCount == 0)
    itemCount = [list count];

  [delegate WriteString: "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n" ];
  [delegate WriteString: "<TiVoContainer>\r\n" ];
  sprintf(tmp,        "    <ItemStart>%d</ItemStart>\r\n", i);
  [delegate WriteString: tmp ];
  sprintf(tmp,        "    <ItemCount>%d</ItemCount>\r\n",
               [list count] < itemCount ? [list count] : itemCount);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    <Details>\r\n" ];
  sprintf(tmp,        "       <Title>%s</Title>\r\n", [[self urlDecode: symbolicPath] UTF8String]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "        <ContentType>x-container/folder</ContentType>\r\n" ];
  [delegate WriteString: "        <SourceFormat>x-container/folder</SourceFormat>\r\n" ];
  sprintf(tmp,        "        <TotalItems>%d</TotalItems>\r\n", [list count]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    </Details>\r\n" ];


  syslog(LOG_DEBUG, "Writing XML entries (%d-%d of %d)...", i, i+itemCount, [list count]);
  int j = 0;
  for (j = 0; i < [list count] && j < itemCount; i++, j++) {
    MusicFileEntry *item = [list objectAtIndex:i];

    [delegate WriteString: "    <Item>\r\n" ];
    [delegate WriteString: "        <Details>\r\n" ];
    sprintf(tmp,           "            <Title>%s</Title>\r\n", 
              [[self urlDecode: item->name] UTF8String]);
    [delegate WriteString: tmp ];

    /* check if directory or file */
    if (item->type == 0) {
      [delegate WriteString: "          <ContentType>x-tivo-container/folder</ContentType>\r\n" ];
    } else if (item->type == 1) {
      [delegate WriteString: "          <ContentType>audio/mpeg</ContentType>\r\n" ];

      if (item->title && [item->title length] > 0)
        sprintf(tmp,           "          <SongTitle>%s</SongTitle>\r\n", 
              [[self urlDecode: item->title] UTF8String]);
      else
        sprintf(tmp,           "          <SongTitle>%s</SongTitle>\r\n", 
              [[self urlDecode: item->name] UTF8String]);
      [delegate WriteString: tmp ];

      if (item->artist && [item->artist length] > 0) {
        sprintf(tmp,         "          <ArtistName>%s</ArtistName>\r\n", 
            [[self urlDecode: item->artist] UTF8String]);
        [delegate WriteString: tmp ];
      }

      if (item->album && [item->album length] > 0) {
        sprintf(tmp,         "          <AlbumTitle>%s</AlbumTitle>\r\n", 
             [[self urlDecode: item->album] UTF8String]);
        [delegate WriteString: tmp ];
      }

      if (item->year && [item->year length] > 0) {
        sprintf(tmp,         "          <AlbumYear>%s</AlbumYear>\r\n", [item->year UTF8String]);
        [delegate WriteString: tmp ];
      }

      if (item->genre && [item->genre length] > 0) {
        sprintf(tmp,         "          <MusicGenre>%s</MusicGenre>\r\n", [item->genre UTF8String]);
        [delegate WriteString: tmp ];
      }

      if (item->duration > 0) {
        sprintf(tmp,         "          <Duration>%d</Duration>\r\n", item->duration);
        [delegate WriteString: tmp ];
      }
    } else if (item->type == 2) {
      [delegate WriteString: "          <ContentType>x-tivo-container/playlist</ContentType>\r\n" ];
    }

    [delegate WriteString: "       </Details>\r\n" ];
    [delegate WriteString: "       <Links>\r\n" ];
    [delegate WriteString: "           <Content>\r\n" ];

    if (item->type == 0) {
      sprintf(tmp, "               <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s/%s</Url>\r\n",
          [[self urlEncode: realPath] UTF8String],
          [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
      [delegate WriteString: "               <ContentType>x-tivo-container/folder</ContentType>\r\n" ];
    } else if (item->type == 1) {
      [delegate WriteString: "               <ContentType>audio/mpeg</ContentType>\r\n" ];
      [delegate WriteString: "               <AcceptsParams>Yes</AcceptsParams>\r\n" ];

      if (item->path)
        sprintf(tmp, "               <Url>%s</Url>\r\n",
            [[self urlEncode: item->path] UTF8String]);
      else
        sprintf(tmp, "               <Url>/%s/%s</Url>\r\n",
            [[self urlEncode: realPath] UTF8String],
            [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
    } else if (item->type == 2) {
      /* playlist item */
      sprintf(tmp, "               <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s/%s</Url>\r\n",
          [[self urlEncode: realPath] UTF8String],
          [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
      [delegate WriteString: "               <ContentType>x-tivo-container/playlist</ContentType>\r\n" ];
    }

    [delegate WriteString: "           </Content>\r\n" ];
    [delegate WriteString: "       </Links>\r\n" ];
    [delegate WriteString: "    </Item>\r\n" ];
  }

  [delegate WriteString: "</TiVoContainer>\r\n" ];

  syslog(LOG_DEBUG, "Music QueryContainer finished.");
}

@end;




