# SubScrub GUI v1.1 - Quick Start Guide

## 🚀 Building the Application

### Step 1: Build the EXE
```batch
BUILD-GUI.bat
```
This will:
- Install PS2EXE if needed
- Compile SubScrub-GUI-v1.1.ps1 → SubScrub-GUI.exe
- Embed SubScrub.ico (if present)
- Create a standalone executable

---

## 📋 Using SubScrub

### Basic Workflow

1. **Select Media Directory**
   - Browse to your media folder (local or network)
   - Network paths: Use UNC format `\\server\share`

2. **Choose Language to Keep**
   - Select primary language (e.g., English)
   - Add additional languages: `spa, fre, rus`

3. **Set Backup Location**
   - Where archived subtitles will be stored
   - Creates timestamped folders automatically

4. **Configure Options**
   - ✅ **Dry Run:** Preview changes without modifying files
   - ✅ **Clean up empty folders:** Remove empty dirs after archiving
   - ✅ **Generate CSV report:** Create detailed log file

5. **Click Start!**

---

## ⚙️ All Features

### Core Features
- ✅ Multi-language subtitle filtering
- ✅ Recursive directory scanning with depth limits
- ✅ Safe backup before deletion
- ✅ Pause/Resume/Stop controls
- ✅ Real-time progress updates
- ✅ Dark theme UI

### NEW Features (Just Added!)
- ✅ **CSV Report Generation** - Detailed logs of all operations
- ✅ **Empty Folder Cleanup** - Automatic removal of empty directories

### File Support
- `.srt` - SubRip subtitles
- `.vtt` - WebVTT subtitles
- `.ass` - Advanced SubStation Alpha
- `.sub` - MicroDVD subtitles
- `.ssa` - SubStation Alpha

### Language Support
- English, Spanish, French, German, Italian, Portuguese
- Japanese, Chinese, Korean, Russian, Dutch, Polish
- Custom language codes supported

---

## 🎯 Example Scenarios

### Scenario 1: Clean Up Movie Collection
**Goal:** Keep only English subtitles, remove Spanish/French/etc.

1. Source: `D:\Movies`
2. Language: `English`
3. Options: ✅ Dry Run first to preview
4. Run → Review log → Uncheck Dry Run → Run again

### Scenario 2: Keep Multiple Languages
**Goal:** Keep English AND Spanish subtitles

1. Source: `\\NAS\Media\TV Shows`
2. Language: `English`
3. Additional: `spa, spanish, es`
4. Max depth: `10 levels` (for large shares)
5. Options: ✅ Generate CSV report

### Scenario 3: Network Share Cleanup
**Goal:** Clean large network share, track everything

1. Source: `\\server\media`
2. Depth: `5 levels` (limit scan depth)
3. Options:
   - ✅ Dry Run
   - ✅ Generate CSV report
   - ✅ Clean up empty folders
4. Review CSV report before running live

---

## 📊 CSV Report Format

**Location:** `[Source Directory]\SubScrub_Report_YYYYMMDD_HHMMSS.csv`

**Columns:**
- `FileName` - Name of subtitle file
- `FilePath` - Directory location
- `SizeKB` - File size in kilobytes
- `DetectedLanguage` - Auto-detected language code
- `Action` - "Kept", "Archived", or "Would Archive" (dry run)
- `Extension` - File extension (.srt, .vtt, etc.)
- `LastModified` - Last modification timestamp

**Example:**
```csv
FileName,FilePath,SizeKB,DetectedLanguage,Action,Extension,LastModified
Movie.eng.srt,D:\Movies\Action,25.3,eng,Kept,.srt,2024-12-15 10:30:00
Movie.spa.srt,D:\Movies\Action,23.1,spa,Archived,.srt,2024-12-15 10:30:00
```

---

## ⚠️ Safety Features

### Automatic Backups
- All removed subtitles are **moved** (not deleted)
- Backup location: `[Backup Path]\Backup_YYYYMMDD_HHMMSS\`
- Original folder structure preserved

### Excluded Folders
These are never touched:
- `$RECYCLE.BIN`
- `@eaDir` (Synology)
- `#recycle`
- `.appledouble`
- `extras`
- `Backup_*`
- `Media_SRT_Backup`
- `_Backup`

### Dry Run Mode
- No files moved or deleted
- Preview exactly what will happen
- Generate reports without changes

---

## 🎮 Controls

### During Operation
- **Pause** - Temporarily halt processing (resumes from current position)
- **Resume** - Continue after pause
- **Stop** - Abort operation (files processed so far remain changed)

### After Completion
- Check log for summary
- Review CSV report (if enabled)
- Verify backup folder contents
- Re-run if needed

---

## 💡 Pro Tips

1. **Always Dry Run First** - Preview before making changes
2. **Generate CSV Reports** - Keep records of all operations
3. **Use Depth Limits on Networks** - Speeds up scanning on large shares
4. **Check Backups** - Verify backup folder before cleanup
5. **Multiple Languages** - Add custom codes in "Additional" field
6. **Empty Folder Cleanup** - Enable to remove clutter after archiving

---

## 🐛 Troubleshooting

### "No files found"
- Check source path is correct
- Verify subtitle files exist
- Check folder depth limit
- Ensure files aren't in excluded folders

### Network scan is slow
- Use depth limit (3-10 levels)
- Consider smaller source directory
- Check network connection

### Files not archived
- Verify language detection is correct
- Check additional language codes
- Review CSV report for details

### Empty folders not removed
- Only works in Live mode (not Dry Run)
- Some folders may be in use/locked
- Check log for removal count

---

## 📁 File Structure

```
SubScrub-GUI-v1.1/
├── SubScrub-GUI-v1.1.ps1    # Source PowerShell script
├── BUILD-GUI.bat             # Build script
├── SubScrub.ico             # Application icon (optional)
├── SubScrub-GUI.exe         # Compiled executable (after build)
├── FEATURES-ADDED.md        # Feature documentation
└── QUICK-START.md           # This file
```

---

## 🎉 You're Ready!

Run `BUILD-GUI.bat` to create the executable, then start cleaning up those subtitle files!

**Remember:** Dry Run first, then run for real! 🚀
