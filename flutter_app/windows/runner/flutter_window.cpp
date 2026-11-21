#include "flutter_window.h"

#include <commctrl.h>
#include <commdlg.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr UINT_PTR kNoA11yCrashSubclassId = 5101;

// Chống lỗi crash UIA WM_GETOBJECT trong Flutter 3.50 Windows engine khi reparent node
LRESULT CALLBACK FlutterViewSafeSubclassProc(HWND hwnd,
                                             UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam,
                                             UINT_PTR /*subclass_id*/,
                                             DWORD_PTR /*ref_data*/) {
  if (message == WM_GETOBJECT) {
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return L"";
  int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(),
                                static_cast<int>(s.size()), nullptr, 0);
  if (len <= 0) return L"";
  std::wstring out(static_cast<size_t>(len), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                      out.data(), len);
  return out;
}

std::string WideToUtf8(const std::wstring& s) {
  if (s.empty()) return "";
  int len = WideCharToMultiByte(CP_UTF8, 0, s.c_str(),
                                static_cast<int>(s.size()), nullptr, 0,
                                nullptr, nullptr);
  if (len <= 0) return "";
  std::string out(static_cast<size_t>(len), '\0');
  WideCharToMultiByte(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                      out.data(), len, nullptr, nullptr);
  return out;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  file_dialog_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "src_ces.native/file_dialog",
          &flutter::StandardMethodCodec::GetInstance());

  file_dialog_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "openTextFile") {
          wchar_t szOpen[MAX_PATH * 4] = {};
          std::wstring ofilter;
          ofilter.append(L"SRC-CES Project (*.json)");
          ofilter.push_back(L'\0');
          ofilter.append(L"*.json");
          ofilter.push_back(L'\0');
          ofilter.append(L"All Files (*.*)");
          ofilter.push_back(L'\0');
          ofilter.append(L"*.*");
          ofilter.push_back(L'\0');
          ofilter.push_back(L'\0');

          OPENFILENAMEW ofn{};
          ofn.lStructSize = sizeof(ofn);
          ofn.hwndOwner = GetHandle();
          ofn.lpstrFilter = ofilter.c_str();
          ofn.nFilterIndex = 1;
          ofn.lpstrFile = szOpen;
          ofn.nMaxFile = static_cast<DWORD>(MAX_PATH * 4);
          ofn.lpstrTitle = L"Open SRC-CES Project (.json)";
          ofn.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST |
                      OFN_NOCHANGEDIR;
          if (!GetOpenFileNameW(&ofn)) {
            result->Success(flutter::EncodableValue());
            return;
          }
          HANDLE hIn = CreateFileW(szOpen, GENERIC_READ, FILE_SHARE_READ,
                                   nullptr, OPEN_EXISTING,
                                   FILE_ATTRIBUTE_NORMAL, nullptr);
          if (hIn == INVALID_HANDLE_VALUE) {
            result->Error("IO_ERROR", "Cannot open file.");
            return;
          }
          LARGE_INTEGER sz{};
          GetFileSizeEx(hIn, &sz);
          std::string content;
          if (sz.QuadPart > 0 && sz.QuadPart < 20 * 1024 * 1024) {
            content.resize(static_cast<size_t>(sz.QuadPart));
            DWORD readBytes = 0;
            ReadFile(hIn, content.data(), static_cast<DWORD>(sz.QuadPart),
                     &readBytes, nullptr);
            content.resize(readBytes);
          }
          CloseHandle(hIn);
          result->Success(flutter::EncodableValue(content));
          return;
        }
        if (call.method_name() != "saveFile") {
          result->NotImplemented();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("BAD_ARGS", "Missing arguments.");
          return;
        }
        std::string file_name = "SRC_CES_Report.pdf";
        std::string ext = "pdf";
        std::vector<uint8_t> bytes;
        if (auto it = args->find(flutter::EncodableValue("fileName"));
            it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) {
            file_name = *s;
          }
        }
        if (auto it = args->find(flutter::EncodableValue("ext"));
            it != args->end()) {
          if (const auto* s = std::get_if<std::string>(&it->second)) {
            ext = *s;
          }
        }
        if (auto it = args->find(flutter::EncodableValue("bytes"));
            it != args->end()) {
          if (const auto* b = std::get_if<std::vector<uint8_t>>(&it->second)) {
            bytes = *b;
          }
        }

        wchar_t szFile[MAX_PATH * 4] = {};
        std::wstring wname = Utf8ToWide(file_name);
        if (wname.size() < MAX_PATH * 4 - 1) {
          wcsncpy_s(szFile, wname.c_str(), _TRUNCATE);
        }
        std::wstring wext = Utf8ToWide(ext);
        std::wstring filter;
        if (ext == "docx") {
          filter.append(L"Microsoft Word (*.docx)");
          filter.push_back(L'\0');
          filter.append(L"*.docx");
          filter.push_back(L'\0');
        } else if (ext == "pdf") {
          filter.append(L"PDF Document (*.pdf)");
          filter.push_back(L'\0');
          filter.append(L"*.pdf");
          filter.push_back(L'\0');
        } else if (ext == "dxf") {
          filter.append(L"AutoCAD DXF Drawing (*.dxf)");
          filter.push_back(L'\0');
          filter.append(L"*.dxf");
          filter.push_back(L'\0');
        } else if (ext == "csv") {
          filter.append(L"CSV Table (*.csv)");
          filter.push_back(L'\0');
          filter.append(L"*.csv");
          filter.push_back(L'\0');
        } else if (ext == "json") {
          filter.append(L"SRC-CES Project (*.json)");
          filter.push_back(L'\0');
          filter.append(L"*.json");
          filter.push_back(L'\0');
        }
        filter.append(L"All Files (*.*)");
        filter.push_back(L'\0');
        filter.append(L"*.*");
        filter.push_back(L'\0');
        filter.push_back(L'\0');

        OPENFILENAMEW ofn{};
        ofn.lStructSize = sizeof(ofn);
        ofn.hwndOwner = GetHandle();
        ofn.lpstrFilter = filter.c_str();
        ofn.nFilterIndex = 1;
        ofn.lpstrFile = szFile;
        ofn.nMaxFile = static_cast<DWORD>(MAX_PATH * 4);
        ofn.lpstrDefExt = wext.c_str();
        ofn.lpstrTitle = L"Save SRC-CES Nonlinear Studio Output";
        ofn.Flags = OFN_EXPLORER | OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST |
                    OFN_NOCHANGEDIR;

        if (!GetSaveFileNameW(&ofn)) {
          result->Success(flutter::EncodableValue());
          return;
        }
        HANDLE hFile = CreateFileW(szFile, GENERIC_WRITE, 0, nullptr,
                                   CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                                   nullptr);
        if (hFile == INVALID_HANDLE_VALUE) {
          result->Error("IO_ERROR", "Cannot create output file.");
          return;
        }
        DWORD written = 0;
        BOOL ok = TRUE;
        if (!bytes.empty()) {
          ok = WriteFile(hFile, bytes.data(),
                         static_cast<DWORD>(bytes.size()), &written, nullptr);
        }
        CloseHandle(hFile);
        if (!ok || written != static_cast<DWORD>(bytes.size())) {
          result->Error("IO_ERROR", "Failed writing output file.");
          return;
        }
        result->Success(
            flutter::EncodableValue(WideToUtf8(std::wstring(szFile))));
      });

  flutter_view_hwnd_ = flutter_controller_->view()->GetNativeWindow();
  if (flutter_view_hwnd_ != nullptr) {
    SetWindowSubclass(flutter_view_hwnd_, FlutterViewSafeSubclassProc,
                      kNoA11yCrashSubclassId, 0);
  }
  SetChildContent(flutter_view_hwnd_);

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  file_dialog_channel_.reset();
  if (flutter_view_hwnd_ != nullptr) {
    RemoveWindowSubclass(flutter_view_hwnd_, FlutterViewSafeSubclassProc,
                         kNoA11yCrashSubclassId);
    flutter_view_hwnd_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_GETOBJECT) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }
  if (message == WM_FONTCHANGE && flutter_controller_) {
    flutter_controller_->engine()->ReloadSystemFonts();
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
