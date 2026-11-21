# -*- coding: utf-8 -*-
"""
================================================================================
ĐÓNG GÓI ỨNG DỤNG FLUTTER WINDOWS THÀNH MỘT TỆP .EXE ĐỘC LẬP DUY NHẤT
================================================================================
Sử dụng trình khởi chạy Win32 C++ NATIVE thuần túy (KHÔNG dùng PyInstaller ->
không tạo thư mục tạm _MEI và chạy ngay trên mọi máy tính Windows 10/11 khác
mà không cần cài Python hay Flutter).

Đầu ra:
  releases/SRC_CES_NonlinearStudio_Windows_x64.exe
================================================================================
"""

from __future__ import annotations
import hashlib
import os
import subprocess
import zipfile


def _find_vcvars64() -> str:
    vswhere = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if os.path.exists(vswhere):
        out = subprocess.check_output(
            [vswhere, "-latest", "-products", "*", "-requires",
             "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"],
            text=True,
        ).strip()
        if out:
            vc = os.path.join(out, "VC", "Auxiliary", "Build", "vcvars64.bat")
            if os.path.exists(vc):
                return vc
    for year in ("2022", "2019"):
        for ed in ("Community", "Professional", "Enterprise", "BuildTools"):
            vc = rf"C:\Program Files\Microsoft Visual Studio\{year}\{ed}\VC\Auxiliary\Build\vcvars64.bat"
            if os.path.exists(vc):
                return vc
    raise RuntimeError("Không tìm thấy Visual Studio C++ vcvars64.bat!")


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    gui_rel = os.path.join(root, "flutter_app", "build", "windows", "x64", "runner", "Release")
    icon_path = os.path.join(root, "flutter_app", "windows", "runner", "resources", "app_icon.ico")
    build_tmp = os.path.join(root, "scripts", "_build_single_exe")
    os.makedirs(build_tmp, exist_ok=True)
    payload_zip = os.path.join(build_tmp, "src_ces_payload.zip")

    print("1. Nén gói Flutter Windows Release thành payload ZIP...")
    with zipfile.ZipFile(payload_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for dirpath, _, filenames in os.walk(gui_rel):
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, gui_rel)
                zf.write(full, rel)

    h = hashlib.sha256()
    with open(payload_zip, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    stamp = h.hexdigest()[:16]
    print(f"   Payload ZIP: {os.path.getsize(payload_zip)/(1024*1024):.2f} MB (stamp={stamp})")

    rc_path = os.path.join(build_tmp, "launcher.rc")
    with open(rc_path, "w", encoding="utf-8") as f:
        ico_esc = icon_path.replace("\\", "\\\\")
        zip_esc = payload_zip.replace("\\", "\\\\")
        if os.path.exists(icon_path):
            f.write(f'101 ICON "{ico_esc}"\n')
        f.write(f'102 RCDATA "{zip_esc}"\n')

    cpp_path = os.path.join(build_tmp, "native_launcher.cpp")
    cpp_code = r'''#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <string>
#include <vector>

#ifndef PAYLOAD_STAMP
#define PAYLOAD_STAMP "v1"
#endif

static bool FileExistsW(const std::wstring& p) {
    DWORD a = GetFileAttributesW(p.c_str());
    return (a != INVALID_FILE_ATTRIBUTES) && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

static bool RunHiddenAndWait(std::wstring cmdLine, const std::wstring& workDir) {
    STARTUPINFOW si{};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi{};
    std::vector<wchar_t> buf(cmdLine.begin(), cmdLine.end());
    buf.push_back(L'\0');
    if (!CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr,
                        workDir.empty() ? nullptr : workDir.c_str(), &si, &pi)) {
        return false;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return code == 0;
}

static std::string ReadTextFile(const std::wstring& path) {
    HANDLE h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return "";
    char buf[128] = {};
    DWORD read = 0;
    ReadFile(h, buf, sizeof(buf) - 1, &read, nullptr);
    CloseHandle(h);
    return std::string(buf, read);
}

static bool WriteBufferToFile(const std::wstring& path, const void* data, DWORD size) {
    HANDLE h = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    BOOL ok = WriteFile(h, data, size, &written, nullptr);
    CloseHandle(h);
    return ok && written == size;
}

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE, PWSTR, int) {
    wchar_t localAppData[MAX_PATH] = {};
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, localAppData))) {
        GetTempPathW(MAX_PATH, localAppData);
    }

    const std::string expectedStamp = PAYLOAD_STAMP;
    std::wstring wStamp(expectedStamp.begin(), expectedStamp.end());
    std::wstring targetDir = std::wstring(localAppData) + L"\\SRC_CES_NonlinearStudio_" + wStamp;
    CreateDirectoryW(targetDir.c_str(), nullptr);

    std::wstring exePath = targetDir + L"\\src_ces_studio.exe";
    std::wstring stampPath = targetDir + L"\\.stamp";

    bool needExtract = !FileExistsW(exePath) || (ReadTextFile(stampPath) != expectedStamp);
    if (needExtract) {
        HRSRC hRes = FindResourceW(hInst, MAKEINTRESOURCEW(102), RT_RCDATA);
        if (!hRes) {
            MessageBoxW(nullptr, L"Không tìm thấy dữ liệu đóng gói ứng dụng.",
                        L"SRC-CES Nonlinear Studio", MB_ICONERROR);
            return 1;
        }
        DWORD resSize = SizeofResource(hInst, hRes);
        HGLOBAL hMem = LoadResource(hInst, hRes);
        const void* pData = hMem ? LockResource(hMem) : nullptr;
        if (!pData || resSize == 0) {
            MessageBoxW(nullptr, L"Không thể đọc dữ liệu đóng gói ứng dụng.",
                        L"SRC-CES Nonlinear Studio", MB_ICONERROR);
            return 1;
        }

        std::wstring zipPath = targetDir + L"\\_payload.zip";
        if (!WriteBufferToFile(zipPath, pData, resSize)) {
            MessageBoxW(nullptr, L"Không thể ghi tệp giải nén tạm.",
                        L"SRC-CES Nonlinear Studio", MB_ICONERROR);
            return 1;
        }

        std::wstring tarCmd = L"tar.exe -xf \"" + zipPath + L"\" -C \"" + targetDir + L"\"";
        bool ok = RunHiddenAndWait(tarCmd, targetDir);
        if (!ok) {
            std::wstring psCmd =
                L"powershell.exe -NoProfile -WindowStyle Hidden -Command \"Expand-Archive -LiteralPath '" +
                zipPath + L"' -DestinationPath '" + targetDir + L"' -Force\"";
            ok = RunHiddenAndWait(psCmd, targetDir);
        }
        DeleteFileW(zipPath.c_str());

        if (!ok || !FileExistsW(exePath)) {
            MessageBoxW(nullptr, L"Giải nén ứng dụng thất bại.",
                        L"SRC-CES Nonlinear Studio", MB_ICONERROR);
            return 1;
        }
        WriteBufferToFile(stampPath, expectedStamp.data(), static_cast<DWORD>(expectedStamp.size()));
    }

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi{};
    std::wstring launchCmd = L"\"" + exePath + L"\"";
    std::vector<wchar_t> cmdBuf(launchCmd.begin(), launchCmd.end());
    cmdBuf.push_back(L'\0');
    if (!CreateProcessW(exePath.c_str(), cmdBuf.data(), nullptr, nullptr, FALSE,
                        0, nullptr, targetDir.c_str(), &si, &pi)) {
        MessageBoxW(nullptr, L"Không thể khởi chạy src_ces_studio.exe.",
                    L"SRC-CES Nonlinear Studio", MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
'''
    with open(cpp_path, "w", encoding="utf-8") as f:
        f.write(cpp_code)

    out_dir = os.path.join(root, "releases")
    os.makedirs(out_dir, exist_ok=True)
    out_exe = os.path.join(out_dir, "SRC_CES_NonlinearStudio_Windows_x64.exe")

    vcvars = _find_vcvars64()
    res_file = os.path.join(build_tmp, "launcher.res")
    obj_file = os.path.join(build_tmp, "native_launcher.obj")
    bat_path = os.path.join(build_tmp, "compile_launcher.bat")
    with open(bat_path, "w", encoding="utf-8") as f:
        f.write("@echo off\n")
        f.write(f'call "{vcvars}" >nul\n')
        f.write(f'rc.exe /nologo /fo "{res_file}" "{rc_path}" || exit /b 1\n')
        f.write(
            f'cl.exe /nologo /O2 /MT /EHsc /W3 /DPAYLOAD_STAMP="\\"{stamp}\\"" '
            f'/Fo"{obj_file}" /c "{cpp_path}" || exit /b 1\n'
        )
        f.write(
            f'link.exe /nologo /SUBSYSTEM:WINDOWS /OUT:"{out_exe}" '
            f'"{obj_file}" "{res_file}" kernel32.lib user32.lib shell32.lib || exit /b 1\n'
        )

    print("2. Biên dịch trình khởi chạy Win32 C++ Native (.exe độc lập)...")
    subprocess.run(["cmd.exe", "/c", bat_path], check=True)
    sz_mb = os.path.getsize(out_exe) / (1024 * 1024)
    print(f"HOÀN TẤT NATIVE EXE: {out_exe} ({sz_mb:.2f} MB)")


if __name__ == "__main__":
    main()
