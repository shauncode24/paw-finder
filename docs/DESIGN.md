# PawFinder Design: Color Scheme

Define these once as color sets (Any/Dark appearances) in the DesignSystem package asset catalog. Feature code uses the tokens, never raw hex.

| Token | Name | Light | Dark | Usage |
|---|---|---|---|---|
| `background` | App Background | `#F6F2EF` | `#171615` | Main screen background |
| `surface` | Primary Surface | `#FBFAF8` | `#242120` | Cards and navigation |
| `surfaceElevated` | Elevated Surface | `#FFFFFF` | `#302B29` | Sheets, dialogs, input fields |
| `brandPrimary` | Brand Rose | `#B76F5D` | `#CE8E7D` | Primary buttons and brand accents |
| `brandLight` | Light Rose | `#CE8E7D` | `#E3B4A7` | Icons, selected states, highlights |
| `brandDeep` | Deep Rose | `#F2E1DC` | `#49332F` | Selected chips and subtle accent backgrounds |
| `textPrimary` | Primary Text | `#171615` | `#F6F0EC` | Headings and important labels |
| `textSecondary` | Secondary Text | `#716761` | `#B7AAA4` | Descriptions and metadata |
| `border` | Borders | `#E7E2DE` | `#403936` | Dividers and card outlines |
| `error` | Error | `#B93838` | `#F28B82` | Errors and critical alerts |
| `success` | Success | `#34734A` | `#9CC7A5` | Successful application status |

Support system appearance switching plus a manual override in settings.
