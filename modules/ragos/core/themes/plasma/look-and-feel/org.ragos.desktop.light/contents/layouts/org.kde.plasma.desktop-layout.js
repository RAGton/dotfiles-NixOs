var ragosFavorites = [
    "org.kde.dolphin.desktop",
    "org.kde.konsole.desktop"
];

var ragosSystemApplications = [
    "systemsettings.desktop"
];

var ragosWallpaperDir = "file:///run/current-system/sw/share/wallpapers/org.ragos.wallpaper.light/contents/slides";
var ragosWallpaperFeatured = "file:///run/current-system/sw/share/wallpapers/org.ragos.wallpaper.light/contents/slides/01.png";
var ragosWallpaperInterval = 1200;

function configureSystemTray(widget) {
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("showAllItems", true);
    widget.writeConfig("hiddenItems", []);
    widget.writeConfig("disabledStatusNotifiers", []);
    widget.reloadConfig();
}

function configureKickoff(widget) {
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("icon", "ragos-control");
    widget.writeConfig("menuLabel", "");
    widget.writeConfig("appNameFormat", 1);
    widget.writeConfig("favorites", ragosFavorites);
    widget.writeConfig("favoritesPortedToKAstats", false);
    widget.writeConfig("systemApplications", ragosSystemApplications);
    widget.writeConfig("highlightNewlyInstalledApps", false);
    widget.reloadConfig();
}

var panel = new Panel;
var panelScreen = panel.screen;

const maximumAspectRatio = 21 / 9;
if (panel.formFactor === "horizontal") {
    const geo = screenGeometry(panelScreen);
    const maximumWidth = Math.ceil(geo.height * maximumAspectRatio);

    if (geo.width > maximumWidth) {
        panel.alignment = "center";
        panel.minimumLength = maximumWidth;
        panel.maximumLength = maximumWidth;
    }
}

panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2);

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
configureKickoff(kickoff);
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");

var langIds = [
    "as",
    "bn",
    "bo",
    "brx",
    "doi",
    "gu",
    "hi",
    "ja",
    "kn",
    "ko",
    "kok",
    "ks",
    "lep",
    "mai",
    "ml",
    "mni",
    "mr",
    "ne",
    "or",
    "pa",
    "sa",
    "sat",
    "sd",
    "si",
    "ta",
    "te",
    "th",
    "ur",
    "vi",
    "zh_CN",
    "zh_TW"
];

if (langIds.indexOf(languageId) !== -1) {
    panel.addWidget("org.kde.plasma.kimpanel");
}

var systemTray = panel.addWidget("org.kde.plasma.systemtray");
configureSystemTray(systemTray);
panel.addWidget("org.kde.plasma.digitalclock");

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.slideshow";
    desktopsArray[j].currentConfigGroup = ["Wallpaper", "org.kde.slideshow", "General"];
    desktopsArray[j].writeConfig("Image", ragosWallpaperFeatured);
    desktopsArray[j].writeConfig("SlidePaths", [ragosWallpaperDir]);
    desktopsArray[j].writeConfig("SlideInterval", ragosWallpaperInterval);
    desktopsArray[j].writeConfig("SlideshowMode", 0);
    desktopsArray[j].writeConfig("FillMode", 2);
    desktopsArray[j].reloadConfig();
}
