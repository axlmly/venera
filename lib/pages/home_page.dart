import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/accounts_page.dart';
import 'package:venera/pages/comic_page.dart';
import 'package:venera/pages/comic_source_page.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/pages/history_page.dart';
import 'package:venera/pages/search_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/translations.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'dart:math';

import 'local_comics_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const _SearchBar(),
        const _SyncDataWidget(),
        const _History(),
        const _Local(),
        const _ComicSourceWidget(),
        const _AccountsWidget(),
        SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 52,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: context.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              context.to(() => const SearchPage());
            },
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text('Search'.tl, style: ts.s16),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncDataWidget extends StatefulWidget {
  const _SyncDataWidget();

  @override
  State<_SyncDataWidget> createState() => _SyncDataWidgetState();
}

class _SyncDataWidgetState extends State<_SyncDataWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    DataSync().addListener(update);
    WidgetsBinding.instance.addObserver(this);
    lastCheck = DateTime.now();
  }

  void update() {
    if(mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    DataSync().removeListener(update);
    WidgetsBinding.instance.removeObserver(this);
  }

  late DateTime lastCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed) {
      if(DateTime.now().difference(lastCheck) > const Duration(minutes: 10)) {
        lastCheck = DateTime.now();
        DataSync().downloadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if(!DataSync().isEnabled) {
      child = const SliverPadding(padding: EdgeInsets.zero);
    } else if (DataSync().isUploading || DataSync().isDownloading) {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Syncing Data'.tl),
            trailing: const CircularProgressIndicator(strokeWidth: 2)
                .fixWidth(18)
                .fixHeight(18),
          ),
        ),
      );
    } else {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Sync Data'.tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: () async {
                    DataSync().uploadData();
                  }
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () async {
                    DataSync().downloadData();
                  }
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverAnimatedPaintExtent(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class _History extends StatefulWidget {
  const _History();

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late List<History> history;
  late int count;

  void onHistoryChange() {
    setState(() {
      history = HistoryManager().getRecent();
      count = HistoryManager().count();
    });
  }

  @override
  void initState() {
    history = HistoryManager().getRecent();
    count = HistoryManager().count();
    HistoryManager().addListener(onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(onHistoryChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const HistoryPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('History'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(count.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (history.isNotEmpty)
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      var cover = history[index].cover;
                      ImageProvider imageProvider = CachedImageProvider(
                        cover,
                        sourceKey: history[index].type.comicSource?.key,
                        cid: history[index].id,
                      );
                      if (!cover.isURL) {
                        var localComic = LocalManager().find(
                          history[index].id,
                          history[index].type,
                        );
                        if (localComic != null) {
                          imageProvider = FileImage(localComic.coverFile);
                        }
                      }
                      return InkWell(
                        onTap: () {
                          context.to(
                            () => ComicPage(
                              id: history[index].id,
                              sourceKey: history[index].type.sourceKey,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 92,
                          height: 114,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: imageProvider,
                            width: 96,
                            height: 128,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingHorizontal(8).paddingBottom(16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Local extends StatefulWidget {
  const _Local();

  @override
  State<_Local> createState() => _LocalState();
}

class _LocalState extends State<_Local> {
  late List<LocalComic> local;
  late int count;

  void onLocalComicsChange() {
    setState(() {
      local = LocalManager().getRecent();
      count = LocalManager().count;
    });
  }

  @override
  void initState() {
    local = LocalManager().getRecent();
    count = LocalManager().count;
    LocalManager().addListener(onLocalComicsChange);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(onLocalComicsChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const LocalComicsPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('Local'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(count.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (local.isNotEmpty)
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: local.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          local[index].read();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 92,
                          height: 114,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedImage(
                            image: FileImage(
                              local[index].coverFile,
                            ),
                            width: 96,
                            height: 128,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingHorizontal(8),
              Row(
                children: [
                  if (LocalManager().downloadingTasks.isNotEmpty)
                    Button.outlined(
                      child: Row(
                        children: [
                          if (LocalManager().downloadingTasks.first.isPaused)
                            const Icon(Icons.pause_circle_outline, size: 18)
                          else
                            const _AnimatedDownloadingIcon(),
                          const SizedBox(width: 8),
                          Text("@a Tasks".tlParams({
                            'a': LocalManager().downloadingTasks.length,
                          })),
                        ],
                      ),
                      onPressed: () {
                        showPopUpWidget(context, const DownloadingPage());
                      },
                    ),
                  const Spacer(),
                  Button.filled(
                    onPressed: import,
                    child: Text("Import".tl),
                  ),
                ],
              ).paddingHorizontal(16).paddingVertical(8),
            ],
          ),
        ),
      ),
    );
  }

  void import() {
    showDialog(
      barrierDismissible: false,
      context: App.rootContext,
      builder: (context) {
        return const _ImportComicsWidget();
      },
    );
  }
}

class _ImportComicsWidget extends StatefulWidget {
  const _ImportComicsWidget();

  @override
  State<_ImportComicsWidget> createState() => _ImportComicsWidgetState();
}

class _ImportComicsWidgetState extends State<_ImportComicsWidget> {
  int type = 0;

  bool loading = false;

  var key = GlobalKey();

  var height = 200.0;

  var folders = LocalFavoritesManager().folderNames;

  String? selectedFolder;

  @override
  void dispose() {
    loading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String info = [
      "Select a directory which contains the comic files.".tl,
      "Select a directory which contains the comic directories.".tl,
      "Select a cbz file.".tl,
      "Select an EhViewer database and a download folder.".tl
    ][type];
    List<String> importMethods = [
      "Single Comic".tl,
      "Multiple Comics".tl,
      "A cbz file".tl,
      "EhViewer downloads".tl
    ];

    return ContentDialog(
      dismissible: !loading,
      title: "Import Comics".tl,
      content: loading
          ? SizedBox(
              width: 600,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 600),
                ...List.generate(importMethods.length, (index) {
                  return RadioListTile(
                    title: Text(importMethods[index]),
                    value: index,
                    groupValue: type,
                    onChanged: (value) {
                      setState(() {
                        type = value as int;
                      });
                    },
                  );
                }),
                ListTile(
                  title: Text("Add to favorites".tl),
                  trailing: Select(
                    current: selectedFolder,
                    values: folders,
                    minWidth: 112,
                    onTap: (v) {
                      setState(() {
                        selectedFolder = folders[v];
                      });
                    },
                  ),
                ).paddingHorizontal(8),
                const SizedBox(height: 8),
                Text(info).paddingHorizontal(24),
              ],
            ),
      actions: [
        Button.text(
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text("help".tl),
            ],
          ),
          onPressed: () {
            showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.2),
              builder: (context) {
                var help = '';
                help +=
                    '${"A directory is considered as a comic only if it matches one of the following conditions:".tl}\n';
                help += '${'1. The directory only contains image files.'.tl}\n';
                help +=
                    '${'2. The directory contains directories which contain image files. Each directory is considered as a chapter.'.tl}\n\n';
                help +=
                    '${"If the directory contains a file named 'cover.*', it will be used as the cover image. Otherwise the first image will be used.".tl}\n\n';
                help +=
                    "The directory name will be used as the comic title. And the name of chapter directories will be used as the chapter titles.\n"
                        .tl;
                help +="If you import an EhViewer's database, program will automatically create folders according to the download label in that database.".tl;
                return ContentDialog(
                  title: "Help".tl,
                  content: Text(help).paddingHorizontal(16),
                  actions: [
                    Button.filled(
                      child: Text("OK".tl),
                      onPressed: () {
                        context.pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        ).fixWidth(90).paddingRight(8),
        Button.filled(
          isLoading: loading,
          onPressed: selectAndImport,
          child: Text("Select".tl),
        )
      ],
    );
  }

  void selectAndImport() async {
    if (type == 2) {
      var xFile = await selectFile(ext: ['cbz']);
      var controller = showLoadingDialog(context, allowCancel: false);
      try {
        var cache = FilePath.join(App.cachePath, xFile?.name ?? 'temp.cbz');
        await xFile!.saveTo(cache);
        var comic = await CBZ.import(File(cache));
        if (selectedFolder != null) {
          LocalFavoritesManager().addComic(
              selectedFolder!,
              FavoriteItem(
                id: comic.id,
                name: comic.title,
                coverPath: comic.cover,
                author: comic.subtitle,
                type: comic.comicType,
                tags: comic.tags,
              ));
        }
        await File(cache).deleteIgnoreError();
      } catch (e, s) {
        Log.error("Import Comic", e.toString(), s);
        context.showMessage(message: e.toString());
      }
      controller.close();
      return;
    } else if (type == 3) {
      var dbFile = await selectFile(ext: ['db']);
      final picker = DirectoryPicker();
      final comicSrc = await picker.pickDirectory();
      if (dbFile == null || comicSrc == null) {
        return;
      }

      bool cancelled = false;
      var controller = showLoadingDialog(context, onCancel: () { cancelled = true; });

      try {
        var cache = FilePath.join(App.cachePath, dbFile.name);
        await dbFile.saveTo(cache);
        var db = sql.sqlite3.open(cache);

        Future<void> addTagComics(String destFolder, List<sql.Row> comics) async {
          for(var comic in comics) {
            if(cancelled) {
              return;
            }
            var comicDir = Directory(FilePath.join(comicSrc.path, comic['DIRNAME'] as String));
            if(!(await comicDir.exists())) {
              continue;
            }
            String titleJP = comic['TITLE_JPN'] == null ? "" : comic['TITLE_JPN'] as String;
            String title = titleJP == "" ? comic['TITLE'] as String : titleJP;
            if (LocalManager().findByName(title) != null) {
              Log.info("Import Comic", "Comic already exists: $title");
              continue;
            }
            
            String coverURL = await comicDir.joinFile(".thumb").exists() ? 
              comicDir.joinFile(".thumb").path : 
              (comic['THUMB'] as String).replaceAll('s.exhentai.org', 'ehgt.org');
            int downloadedTimeStamp = comic['TIME'] as int;
            DateTime downloadedTime = 
              downloadedTimeStamp != 0 ? 
              DateTime.fromMillisecondsSinceEpoch(downloadedTimeStamp) : DateTime.now();
            var comicObj = LocalComic(
              id: LocalManager().findValidId(ComicType.local),
              title: title,
              subtitle: '',
              tags: [
                //1 >> x
                [
                  "MISC",
                  "DOUJINSHI",
                  "MANGA",
                  "ARTISTCG",
                  "GAMECG",
                  "IMAGE SET",
                  "COSPLAY",
                  "ASIAN PORN",
                  "NON-H",
                  "WESTERN",
                ][(log(comic['CATEGORY'] as int) / ln2).floor()]
              ],
              directory: comicDir.path,
              chapters: null,
              cover: coverURL,
              comicType: ComicType.local,
              downloadedChapters: [],
              createdAt: downloadedTime,
            );
            LocalManager().add(comicObj, comicObj.id);
            LocalFavoritesManager().addComic(
              destFolder,
              FavoriteItem(
                id: comicObj.id,
                name: comicObj.title,
                coverPath: comicObj.cover,
                author: comicObj.subtitle,
                type: comicObj.comicType,
                tags: comicObj.tags,
                favoriteTime: downloadedTime
              ),
            );
          }
        }

        //default folder
        {
          var defaultFolderName = '(EhViewer)Default'.tl;
          if(!LocalFavoritesManager().existsFolder(defaultFolderName)) {
            LocalFavoritesManager().createFolder(defaultFolderName);
          }
          var comicList = db.select("""
              SELECT * 
              FROM DOWNLOAD_DIRNAME DN
              LEFT JOIN DOWNLOADS DL
              ON DL.GID = DN.GID
              WHERE DL.LABEL IS NULL AND DL.STATE = 3
              ORDER BY DL.TIME DESC
            """).toList();
          await addTagComics(defaultFolderName, comicList);
        }

        var folders = db.select("""
            SELECT * FROM DOWNLOAD_LABELS;
          """);

        for (var folder in folders) {
          if(cancelled) {
            break;
          }
          var label = folder["LABEL"] as String;
          var folderName = '(EhViewer)$label';
          if(!LocalFavoritesManager().existsFolder(folderName)) {
            LocalFavoritesManager().createFolder(folderName);
          }
          var comicList = db.select("""
              SELECT * 
              FROM DOWNLOAD_DIRNAME DN
              LEFT JOIN DOWNLOADS DL
              ON DL.GID = DN.GID
              WHERE DL.LABEL = ? AND DL.STATE = 3
              ORDER BY DL.TIME DESC
            """, [label]).toList();
          await addTagComics(folderName, comicList);
        }
        db.dispose();
        await File(cache).deleteIgnoreError();
      } catch (e, s) {
        Log.error("Import Comic", e.toString(), s);
        context.showMessage(message: e.toString());
      }
      controller.close();
      return;
    }
    height = key.currentContext!.size!.height;
    setState(() {
      loading = true;
    });
    final picker = DirectoryPicker();
    final path = await picker.pickDirectory();
    if (!loading) {
      picker.dispose();
      return;
    }
    if (path == null) {
      setState(() {
        loading = false;
      });
      return;
    }
    Map<Directory, LocalComic> comics = {};
    if (type == 0) {
      var result = await checkSingleComic(path);
      if (result != null) {
        comics[path] = result;
      } else {
        context.showMessage(message: "Invalid Comic".tl);
        setState(() {
          loading = false;
        });
        return;
      }
    } else {
      await for (var entry in path.list()) {
        if (entry is Directory) {
          var result = await checkSingleComic(entry);
          if (result != null) {
            comics[entry] = result;
          }
        }
      }
    }
    bool shouldCopy = true;
    for (var comic in comics.keys) {
      if (comic.parent.path == LocalManager().path) {
        shouldCopy = false;
        break;
      }
    }
    if (shouldCopy && comics.isNotEmpty) {
      try {
        // copy the comics to the local directory
        await compute<Map<String, dynamic>, void>(_copyDirectories, {
          'toBeCopied': comics.keys.map((e) => e.path).toList(),
          'destination': LocalManager().path,
        });
      } catch (e) {
        context.showMessage(message: "Failed to import comics".tl);
        Log.error("Import Comic", e.toString());
        setState(() {
          loading = false;
        });
        return;
      }
    }
    for (var comic in comics.values) {
      LocalManager().add(comic, LocalManager().findValidId(ComicType.local));
      if (selectedFolder != null) {
        LocalFavoritesManager().addComic(
            selectedFolder!,
            FavoriteItem(
              id: comic.id,
              name: comic.title,
              coverPath: comic.cover,
              author: comic.subtitle,
              type: comic.comicType,
              tags: comic.tags,
            ));
      }
    }
    context.pop();
    context.showMessage(
        message: "Imported @a comics".tlParams({
      'a': comics.length,
    }));
  }

  static _copyDirectories(Map<String, dynamic> data) {
    var toBeCopied = data['toBeCopied'] as List<String>;
    var destination = data['destination'] as String;
    for (var dir in toBeCopied) {
      var source = Directory(dir);
      var dest = Directory("$destination/${source.name}");
      if (dest.existsSync()) {
        // The destination directory already exists, and it is not managed by the app.
        // Rename the old directory to avoid conflicts.
        Log.info("Import Comic",
            "Directory already exists: ${source.name}\nRenaming the old directory.");
        dest.rename(
            findValidDirectoryName(dest.parent.path, "${dest.path}_old"));
      }
      dest.createSync();
      copyDirectory(source, dest);
    }
  }

  Future<LocalComic?> checkSingleComic(Directory directory) async {
    if (!(await directory.exists())) return null;
    var name = directory.name;
    if (LocalManager().findByName(name) != null) {
      Log.info("Import Comic", "Comic already exists: $name");
      return null;
    }
    bool hasChapters = false;
    var chapters = <String>[];
    var coverPath = ''; // relative path to the cover image
    await for (var entry in directory.list()) {
      if (entry is Directory) {
        hasChapters = true;
        chapters.add(entry.name);
        await for (var file in entry.list()) {
          if (file is Directory) {
            Log.info("Import Comic",
                "Invalid Chapter: ${entry.name}\nA directory is found in the chapter directory.");
            return null;
          }
        }
      } else if (entry is File) {
        if (entry.name.startsWith('cover')) {
          coverPath = entry.name;
        }
        const imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'jpe'];
        if (!coverPath.startsWith('cover') &&
            imageExtensions.contains(entry.extension)) {
          coverPath = entry.name;
        }
      }
    }
    chapters.sort();
    if (hasChapters && coverPath == '') {
      // use the first image in the first chapter as the cover
      var firstChapter = Directory('${directory.path}/${chapters.first}');
      await for (var entry in firstChapter.list()) {
        if (entry is File) {
          coverPath = entry.name;
          break;
        }
      }
    }
    if (coverPath == '') {
      Log.info("Import Comic", "Invalid Comic: $name\nNo cover image found.");
      return null;
    }
    return LocalComic(
      id: '0',
      title: name,
      subtitle: '',
      tags: [],
      directory: directory.name,
      chapters: hasChapters ? Map.fromIterables(chapters, chapters) : null,
      cover: coverPath,
      comicType: ComicType.local,
      downloadedChapters: chapters,
      createdAt: DateTime.now(),
    );
  }
}

class _ComicSourceWidget extends StatefulWidget {
  const _ComicSourceWidget();

  @override
  State<_ComicSourceWidget> createState() => _ComicSourceWidgetState();
}

class _ComicSourceWidgetState extends State<_ComicSourceWidget> {
  late List<String> comicSources;

  void onComicSourceChange() {
    setState(() {
      comicSources = ComicSource.all().map((e) => e.name).toList();
    });
  }

  @override
  void initState() {
    comicSources = ComicSource.all().map((e) => e.name).toList();
    ComicSource.addListener(onComicSourceChange);
    super.initState();
  }

  @override
  void dispose() {
    ComicSource.removeListener(onComicSourceChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const ComicSourcePage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('Comic Source'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Text(comicSources.length.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              if (comicSources.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: comicSources.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e),
                      );
                    }).toList(),
                  ).paddingHorizontal(16).paddingBottom(16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountsWidget extends StatefulWidget {
  const _AccountsWidget();

  @override
  State<_AccountsWidget> createState() => _AccountsWidgetState();
}

class _AccountsWidgetState extends State<_AccountsWidget> {
  late List<String> accounts;

  void onComicSourceChange() {
    setState(() {
      accounts.clear();
      for (var c in ComicSource.all()) {
        if (c.isLogged) {
          accounts.add(c.name);
        }
      }
    });
  }

  @override
  void initState() {
    accounts = [];
    for (var c in ComicSource.all()) {
      if (c.isLogged) {
        accounts.add(c.name);
      }
    }
    ComicSource.addListener(onComicSourceChange);
    super.initState();
  }

  @override
  void dispose() {
    ComicSource.removeListener(onComicSourceChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => const AccountsPage());
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Center(
                      child: Text('Accounts'.tl, style: ts.s18),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(accounts.length.toString(), style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_right),
                  ],
                ),
              ).paddingHorizontal(16),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: accounts.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e),
                    );
                  }).toList(),
                ).paddingHorizontal(16).paddingBottom(16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDownloadingIcon extends StatefulWidget {
  const _AnimatedDownloadingIcon();

  @override
  State<_AnimatedDownloadingIcon> createState() =>
      __AnimatedDownloadingIconState();
}

class __AnimatedDownloadingIconState extends State<_AnimatedDownloadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      lowerBound: -1,
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Transform.translate(
            offset: Offset(0, 18 * _controller.value),
            child: Icon(
              Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}
