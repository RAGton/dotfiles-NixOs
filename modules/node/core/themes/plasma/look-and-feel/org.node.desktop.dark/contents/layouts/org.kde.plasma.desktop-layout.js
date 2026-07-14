var nodeFavorites = [
    "org.kde.dolphin.desktop",
    "org.kde.konsole.desktop"
];

var nodeSystemApplications = [
    "systemsettings.desktop"
];

var nodeWallpaperDir = "file:///run/current-system/sw/share/wallpapers/org.node.wallpaper.dark/contents/slides";
var nodeWallpaperFeatured = "file:///run/current-system/sw/share/wallpapers/org.node.wallpaper.dark/contents/slides/01.png";
var nodeWallpaperInterval = 1200;

function configureSystemTray(widget) {
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("showAllItems", true);
    widget.writeConfig("hiddenItems", []);
    widget.writeConfig("disabledStatusNotifiers", []);
    widget.reloadConfig();
}

function configureKickoff(widget) {
    widget.currentConfigGroup = ["General"];
    widget.writeConfig("icon", "node-control");
    widget.writeConfig("menuLabel", "");
    widget.writeConfig("appNameFormat", 1);
    widget.writeConfig("favorites", nodeFavorites);
    widget.writeConfig("favoritesPortedToKAstats", false);
    widget.writeConfig("systemApplications", nodeSystemApplications);
    widget.writeConfig("highlightNewlyInstalledApps", false);
    widget.reloadConfig();
}

var panel = new Panel;
var panelScreen = panel.screen;

// No need to set panel.location as ShellCorona::addPanel will automatically pick one available edge.
panel.height = 2 * Math.ceil(gridUnit * 2.5 / 2);

// Restrict horizontal panel to a maximum size of a 21:9 monitor.
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

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
configureKickoff(kickoff);
panel.addWidget("org.kde.plasma.icontasks");
panel.addWidget("org.kde.plasma.marginsseparator");

// Add the input method panel only for languages that commonly require it.
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
    desktopsArray[j].writeConfig("Image", nodeWallpaperFeatured);
    desktopsArray[j].writeConfig("SlidePaths", [nodeWallpaperDir]);
    desktopsArray[j].writeConfig("SlideInterval", nodeWallpaperInterval);
    desktopsArray[j].writeConfig("SlideshowMode", 0);
    desktopsArray[j].writeConfig("FillMode", 2);
    desktopsArray[j].reloadConfig();
}
