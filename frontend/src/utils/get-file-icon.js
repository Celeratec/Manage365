import {
  Folder,
  InsertDriveFile,
  Image,
  PictureAsPdf,
  TableChart,
  Code,
  VideoFile,
  AudioFile,
  Archive,
  Description,
  SlideshowOutlined,
  TextSnippet,
} from "@mui/icons-material";

/**
 * Map file extensions to icons and MUI color names.
 * @param {string|undefined} extension - file extension without the dot
 * @param {boolean} isFolder - whether the item is a folder
 * @returns {{ icon: JSX.Element, color: string }}
 */
export const getFileIcon = (extension, isFolder) => {
  if (isFolder) return { icon: <Folder />, color: "info" };
  const iconMap = {
    pdf: { icon: <PictureAsPdf />, color: "error" },
    doc: { icon: <Description />, color: "primary" },
    docx: { icon: <Description />, color: "primary" },
    txt: { icon: <TextSnippet />, color: "action" },
    rtf: { icon: <TextSnippet />, color: "action" },
    jpg: { icon: <Image />, color: "success" },
    jpeg: { icon: <Image />, color: "success" },
    png: { icon: <Image />, color: "success" },
    gif: { icon: <Image />, color: "success" },
    svg: { icon: <Image />, color: "success" },
    webp: { icon: <Image />, color: "success" },
    bmp: { icon: <Image />, color: "success" },
    xlsx: { icon: <TableChart />, color: "success" },
    xls: { icon: <TableChart />, color: "success" },
    csv: { icon: <TableChart />, color: "success" },
    pptx: { icon: <SlideshowOutlined />, color: "warning" },
    ppt: { icon: <SlideshowOutlined />, color: "warning" },
    mp4: { icon: <VideoFile />, color: "secondary" },
    avi: { icon: <VideoFile />, color: "secondary" },
    mov: { icon: <VideoFile />, color: "secondary" },
    mkv: { icon: <VideoFile />, color: "secondary" },
    mp3: { icon: <AudioFile />, color: "secondary" },
    wav: { icon: <AudioFile />, color: "secondary" },
    flac: { icon: <AudioFile />, color: "secondary" },
    zip: { icon: <Archive />, color: "warning" },
    rar: { icon: <Archive />, color: "warning" },
    "7z": { icon: <Archive />, color: "warning" },
    tar: { icon: <Archive />, color: "warning" },
    gz: { icon: <Archive />, color: "warning" },
    js: { icon: <Code />, color: "warning" },
    ts: { icon: <Code />, color: "info" },
    py: { icon: <Code />, color: "info" },
    json: { icon: <Code />, color: "warning" },
    xml: { icon: <Code />, color: "warning" },
    html: { icon: <Code />, color: "warning" },
    css: { icon: <Code />, color: "info" },
  };
  return iconMap[extension?.toLowerCase()] || { icon: <InsertDriveFile />, color: "action" };
};
