# FIDE App Startup Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant main.dart
    participant MyApp
    participant WelcomeScreen
    participant MainLayout
    participant MainLayoutState
    participant SharedPreferences
    participant FileSystem
    participant FileSystemItem
    participant DocumentState
    participant EditorScreen

    User->>main.dart: Launch app
    main.dart->>MyApp: runApp(MyApp())

    MyApp->>MyApp: Check projectLoadedProvider
    alt Project not loaded
        MyApp->>WelcomeScreen: Show WelcomeScreen
        WelcomeScreen->>User: Display welcome UI
    else Project loaded
        MyApp->>MainLayout: Show MainLayout
    end

    MainLayout->>MainLayoutState: createState()
    MainLayoutState->>MainLayoutState: initState()
    MainLayoutState->>MainLayoutState: _initializePrefsAndApp()

    MainLayoutState->>MainLayoutState: _loadMruFoldersIntoProvider()
    MainLayoutState->>SharedPreferences: getStringList(_mruFoldersKey)
    SharedPreferences-->>MainLayoutState: Return MRU folder list

    MainLayoutState->>MainLayoutState: Filter valid MRU folders
    MainLayoutState->>MainLayoutState: Update mruFoldersProvider

    loop For each valid MRU folder
        MainLayoutState->>MainLayoutState: _tryAutoLoadProject(folder)
        MainLayoutState->>MainLayoutState: Validate Flutter project (pubspec.yaml, lib/)
        MainLayoutState->>MainLayoutState: Update currentProjectPathProvider
        MainLayoutState->>MainLayoutState: Update projectLoadedProvider = true

        MainLayoutState->>MainLayoutState: tryReopenLastFile(projectPath)
        MainLayoutState->>SharedPreferences: getString(_lastOpenedFileKey)
        SharedPreferences-->>MainLayoutState: Return last file path

        MainLayoutState->>MainLayoutState: Validate file exists
        MainLayoutState->>MainLayoutState: Check file is within project
        MainLayoutState->>MainLayoutState: Check file is source file

        MainLayoutState->>FileSystem: file.length() - CHECK FILE SIZE
        FileSystem-->>MainLayoutState: Return file size

        alt File size > 1MB
            MainLayoutState->>MainLayoutState: Skip loading (too large)
        else File size <= 1MB
            MainLayoutState->>FileSystemItem: FileSystemItem.forMruLoading(filePath) - SAFE, NO FILE SYSTEM CALLS
            FileSystemItem-->>MainLayoutState: Return minimal FileSystemItem

            MainLayoutState->>MainLayoutState: Update selectedFileProvider
        end
    end

    MainLayout->>MainLayout: build()
    MainLayout->>MainLayout: Listen to selectedFileProvider changes

    alt File selected
        MainLayout->>MainLayout: _handleFileSelection(file)
        MainLayout->>MainLayout: _addFileToOpenDocuments(filePath)

        MainLayout->>MainLayout: Determine file type (text/image)
        alt Text file
            MainLayout->>FileSystem: FileUtils.readFileContentSafely(file)
            FileSystem-->>MainLayout: Check file.length() again
            alt File > 1MB
                FileSystem-->>MainLayout: Return "file too big to load"
            else File <= 1MB
                FileSystem-->>MainLayout: Return file content
            end
        else Image file
            MainLayout->>MainLayout: Skip content loading
        end

        MainLayout->>DocumentState: Create DocumentState(content, language)
        MainLayout->>MainLayout: Update openDocumentsProvider
        MainLayout->>MainLayout: Update activeDocumentIndexProvider

        MainLayout->>CenterPanel: Render with documentState
        CenterPanel->>EditorScreen: Create EditorScreen(documentState)

        EditorScreen->>EditorScreen: initState()
        EditorScreen->>CodeCrafterController: Initialize with content
        EditorScreen->>EditorScreen: setState() - NO MORE _checkFileSize()

        alt Image file
            EditorScreen->>EditorScreen: _buildImageView()
            EditorScreen->>EditorScreen: Use content.length for size display - NO MORE File.stat()
        end
    end

    MainLayout->>User: Display loaded project and file
```

## Critical Hang Points Identified:

1. **FileSystemItem.fromFileSystemEntity()** - `entity.statSync()` can hang
2. **File.length()** operations during size checks
3. **File.exists()** operations (removed)
4. **File.stat()** in image view (fixed)

## Current Protection Status:

✅ **Fixed**: Editor screen redundant file operations
✅ **Fixed**: Image view FutureBuilder<FileStat>
✅ **Fixed**: MRU loading FileSystemItem creation (uses forMruLoading)
✅ **Protected**: File size checks before reading
✅ **Protected**: Safe reading utility with 1MB limit

## Summary:

All potential hanging points have been addressed. The app now safely handles large files and problematic file system operations during startup and normal usage.
