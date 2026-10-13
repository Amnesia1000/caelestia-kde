.pragma library

function isImagePath(p) {
    return /\.(png|jpe?g|gif|webp|bmp)$/i.test(p || "");
}

function localPath(path) {
    path = (path || "").trim();
    if (path.indexOf("file://") === 0)
        path = decodeURIComponent(path.substring(7));
    return path;
}

function fileName(path) {
    return (path || "").replace(/^.*\//, "");
}
