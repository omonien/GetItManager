# GetIt Manager

[![Delphi](https://img.shields.io/badge/Delphi-RAD%20Studio-red.svg)](https://www.embarcadero.com/products/rad-studio)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A powerful, user-friendly replacement for RAD Studio's GetIt Package Manager command-line tool.

## 🌟 Features

- **🔍 Multi-Version Support**: Automatically detects and supports all RAD Studio installations
- **📂 Category-Based Organization**: Organizes packages into logical categories for easy browsing
- **🎯 Flexible Package Selection**: Multiple ways to select packages (individual, ranges, categories)
- **⚡ Reliable Installation**: Bypasses RAD Studio 13's GetItCmd AccessViolation issues
- **📊 Progress Tracking**: Real-time installation progress and success statistics
- **🎨 Clean Console UI**: Professional, color-coded console interface
- **🛡️ Error Handling**: Comprehensive error handling with helpful user guidance

## 🚨 Problem Solved

RAD Studio 13 Athens introduced a regression in `GetItCmd.exe` that causes **AccessViolation errors** when the output is redirected (piped, captured, or saved to files). This affects:

- PowerShell scripts using `|` (pipes)
- Batch files using `>` (redirection)
- .NET Process classes with output redirection
- Any automation tool trying to capture GetItCmd output

**GetIt Manager** solves this by using direct console execution for queries and individual package installations, completely avoiding the problematic output redirection.

## 📋 Package Categories

GetIt Manager automatically organizes packages into these categories:

- **🎨 UI Styles & Themes** - VCL/FMX visual styles and themes
- **🧩 Components & Controls** - UI components and custom controls  
- **📄 Templates & Samples** - Project templates and sample applications
- **🔧 IDE Tools & Wizards** - RAD Studio IDE extensions and wizards
- **📚 Libraries & Frameworks** - Code libraries and development frameworks
- **📊 Reporting Tools** - Report generation and business intelligence tools
- **🗄️ Database Tools** - Database connectivity and management tools
- **🎮 Games & Samples** - Game development samples and demos
- **📱 Mobile Development** - Mobile platform specific tools
- **☁️ Web & Cloud Services** - Web services and cloud integration tools
- **🤖 AI & Machine Learning** - Artificial intelligence and ML tools
- **🔨 Other Tools & Utilities** - Miscellaneous development utilities

## 🚀 Installation

### Option 1: Download Pre-built Executable
1. Download `GetItManager.exe` from the [Releases](../../releases) page
2. Place it anywhere on your system
3. Run directly - no installation required!

### Option 2: Build from Source
1. Ensure you have RAD Studio/Delphi installed
2. Clone this repository
3. Open `GetItManager.dpr` in RAD Studio
4. Build the project (Ctrl+F9)

Or compile from command line:
```cmd
dcc32.exe GetItManager.dpr
```

## 📖 Usage

### Basic Usage
Simply run the executable:
```cmd
GetItManager.exe
```

The application will guide you through:

1. **Version Selection** - Choose your RAD Studio version (if multiple detected)
2. **Package Catalog** - View all available packages organized by category  
3. **Package Selection** - Choose packages using flexible selection methods
4. **Installation** - Install selected packages with progress tracking

### Package Selection Methods

GetIt Manager supports multiple ways to select packages:

#### Individual Numbers
```
1 5 23 45
```

#### Ranges  
```
1-10 25-30
```

#### Category Names (use quotes)
```
"UI Styles & Themes" "Components & Controls"
```

#### Mixed Selection
```
1-5 "UI Styles & Themes" 23 45-50
```

#### All Packages
```
all
```

### Examples

**Install all UI styles:**
```
"UI Styles & Themes"
```

**Install specific packages:**
```
1 5 12 25-30
```

**Install components and templates:**
```
"Components & Controls" "Templates & Samples"
```

**Install everything:**
```
all
```

## 🖥️ Screenshots

### Main Interface
```
================================================================
              GetIt Manager v1.0 (Pure Delphi)
================================================================
Complete package management solution for RAD Studio
• Multi-version support
• Category-based package organization  
• Flexible package selection
• Bypasses D13 GetItCmd AccessViolation issues
================================================================
Copyright (c) 2025 Olaf Monien
Licensed under the MIT License
https://github.com/omonien/GetItManager
================================================================

Multiple RAD Studio versions detected:
=====================================
  1 - RAD Studio 13 Athens (v37.0)
      Path: C:\Program Files (x86)\Embarcadero\Studio\37.0
  2 - RAD Studio 12 Yukon (v36.0)
      Path: C:\Program Files (x86)\Embarcadero\Studio\36.0
```

### Package Categories View
```
UI Styles & Themes (56 packages)
--------------------------------------
  [ 31] CopperFMXPremuimStyle (v1.0)
        Free to use FMX Style
  [ 32] CopperVCLPremuimStyle (v1.0)
        Free to use VCL Style
  [171] VCLStyle-Windows11Light (v1.0)
        VCL Windows Style - Windows11 Li
  [168] VCLStyle-Windows11Dark (v1.0)
        VCL Windows Style - Windows11 Da

Components & Controls (28 packages)
-----------------------------------------
  [ 17] BonusKSVC (v8.0.1)
        Konopka Signature VCL Controls 8
  [ 45] DOSCommand-13 (v2025.07)
        TurboPack DOSCommand component l
  [148] ShellBrowser-13 (v12.4)
        ShellBrowser is a component pack
```

## 🛠️ Technical Details

### System Requirements
- **OS**: Windows 10/11
- **RAD Studio**: Any version (10.0 Seattle or newer recommended)
- **Architecture**: 32-bit executable (runs on both 32/64-bit Windows)

### How It Works
1. **Version Detection**: Scans `C:\Program Files (x86)\Embarcadero\Studio\` for installations
2. **Catalog Query**: Uses direct console execution to avoid AccessViolation issues
3. **Package Parsing**: Intelligent parsing with regex for reliable package extraction
4. **Category Assignment**: Smart categorization based on package names and descriptions
5. **Installation**: Individual package installation using direct process execution

### Key Technical Features
- **Pure Delphi**: No external dependencies
- **Direct Execution**: Avoids all output redirection issues
- **Smart Parsing**: Robust package list parsing with regex
- **Error Recovery**: Graceful handling of network/catalog issues
- **Memory Safe**: Proper resource cleanup and exception handling

## 🏆 Recent Improvements

### v1.0.1 (Latest)
- ✅ **Fixed Pagination Issue**: Resolved missing packages after "Press enter to continue" in GetIt catalog
- ✅ **Complete Package Detection**: Now correctly detects all 177 available packages
- ✅ **Enhanced Console Buffer**: Improved console buffer management for reliable package capture
- ✅ **Better Error Handling**: More robust parsing with improved error recovery

### Current Package Statistics
GetIt Manager now correctly detects and categorizes all **177 packages** available in the GetIt catalog:

- **🎨 UI Styles & Themes**: 56 packages
- **🧩 Components & Controls**: 28 packages  
- **📄 Templates & Samples**: 33 packages
- **🔧 Other Tools & Utilities**: 37 packages
- **📚 Libraries & Frameworks**: 9 packages
- **🔧 IDE Tools & Wizards**: 4 packages
- **🎮 Games & Samples**: 4 packages
- **📈 Reporting Tools**: 3 packages
- **🗄️ Database Tools**: 1 package
- **🤖 AI & Machine Learning**: 1 package
- **☁️ Web & Cloud Services**: 1 package

## 🐛 Troubleshooting

### "No RAD Studio installations found"
- Ensure RAD Studio is installed in the standard location
- Check that `GetItCmd.exe` exists in the `bin` directory
- Try running as Administrator

### "Failed to query GetIt catalog"
1. Open RAD Studio IDE
2. Go to **Tools > GetIt Package Manager**
3. Click **"Update Catalog"**
4. Wait for completion and try again
5. Check your internet connection

### Package Installation Fails
- Some packages may already be installed (not an error)
- Check package dependencies in the IDE
- Ensure sufficient disk space
- Try installing individual packages manually to identify issues

### AccessViolation Errors
This tool was specifically created to avoid these! If you still encounter them:
- Make sure you're using the latest version of GetIt Manager
- Report the issue with steps to reproduce

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### Development Setup
1. Clone the repository
2. Open `GetItManager.dpr` in RAD Studio
3. Build and test your changes
4. Submit a pull request with a clear description

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Embarcadero Technologies** - For RAD Studio and the GetIt ecosystem
- **Community Contributors** - For testing and feedback
- **RAD Studio Community** - For identifying the D13 AccessViolation regression

## 📞 Support

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)
- **Wiki**: [Project Wiki](../../wiki)

## 🔄 Version History

### v1.0.1 (Current)
- ✅ **Fixed**: Pagination issue causing missing packages after "Press enter to continue"
- ✅ **Improved**: Enhanced console buffer management for complete package detection
- ✅ **Added**: Copyright and MIT license information in header
- ✅ **Verified**: All 177 GetIt packages now correctly detected and categorized
- ✅ **Enhanced**: More robust package parsing with better error recovery

### v1.0.0 (Initial Release)
- ✅ Multi-version RAD Studio detection
- ✅ Category-based package organization  
- ✅ Flexible package selection methods
- ✅ D13 AccessViolation workaround
- ✅ Professional console interface
- ✅ Comprehensive error handling


---

**Made with ❤️ for the RAD Studio Community**

