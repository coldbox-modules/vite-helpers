# Copilot Instructions for vite-helpers

## Architecture Overview
This ColdBox module provides seamless Vite integration for **BoxLang** (preferred) and legacy CFML engines through two operational modes:
- **Development mode**: Assets served directly from Vite dev server when the hot file exists
- **Production mode**: Assets resolved via Vite manifest (`.vite/manifest.json`) in build directory

The module automatically detects mode by checking for the "hot" file and switches behavior accordingly.

## Engine Preference
- **BoxLang** is the preferred runtime. All new features and examples should target BoxLang first.
- Legacy CFML engines (Lucee, Adobe CF) are supported but secondary.
- BoxLang requires `bx-compat-cfml` and `bx-esapi` modules for CFML interop.

## Application Layouts
- **Flat layout** (traditional CFML): hot file at `/includes/hot`, build at `/includes/build`
- **BoxLang/tiered layout**: hot file at `/public/includes/hot`, build at `/public/includes/build`; use `appRefreshPaths` in `vite.config.js`

## Core Components
- `models/Vite.cfc`: Singleton service handling asset resolution, manifest parsing, and HTML tag generation
- `includes/helpers.cfm`: Exposes global `vite()` function in views via ColdBox's applicationHelper
- `ModuleConfig.cfc`: Configures default paths (`hotFilePath`, `buildDirectory`, `manifestFileName`)

## Key Patterns
- **Dual rendering modes**: `vite()` returns either hot server URLs or manifest-resolved paths
- **Dependency injection**: Settings injected via `box:setting:*@vite-helpers` pattern
- **Tag generation**: Automatic `<script>` and `<link>` tag creation with proper attributes (`type="module"`, preload links)
- **Asset detection**: File extension regex determines CSS vs JS handling

## Usage Examples
```cfml
<!--- Basic usage - outputs appropriate tags for current mode --->
#vite('resources/assets/js/app.js')#

<!--- Returns array of asset paths without rendering --->
#vite().getAssetPaths(['app.js', 'app.css'])#

<!--- Custom configuration --->
#vite().setBuildDirectory('/custom/build').render('app.js')#
```

## Testing Patterns
- Tests in `tests/specs/unit/ViteHelperSpec.cfc` simulate both dev and prod modes
- Use `fileWrite(hotFilePath, serverUrl)` to test dev mode
- Use `fileWrite(manifestFilePath, serializeJSON(manifest))` to test prod mode
- Tests verify exact HTML output including preload tags and module attributes
- CI runs BoxLang first in the matrix; it is not experimental

## Development Workflow
- **Format code**: `box run-script format` (uses cfformat)
- **Run tests**: Navigate to `/tests/runner.cfm` or use TestBox CLI
- **Debug**: Check for manifest file existence and hot file presence in asset resolution logic

## Configuration Points
Default settings (customizable in `ModuleConfig.cfc`) — flat layout:
- `hotFilePath`: `/includes/hot` - signals dev mode when present
- `buildDirectory`: `/includes/build` - where Vite outputs production assets
- `manifestFileName`: `.vite/manifest.json` - Vite's asset manifest file

BoxLang/tiered layout overrides:
- `hotFilePath`: `/public/includes/hot`
- `buildDirectory`: `/public/includes/build`