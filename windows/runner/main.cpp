#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "file_channel.h"     // <-- replaces the bare extern + WideToUtf8
#include "utils.h"
#include <string>

std::string g_opened_file_path;

static bool ForwardToExistingInstance(const std::wstring& path) {
  HANDLE pipe = CreateFileW(
          kPipeName,                    // use the constant from the header
          GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) return false;

  std::string utf8 = WideToUtf8(path);
  DWORD written = 0;
  WriteFile(pipe, utf8.c_str(), static_cast<DWORD>(utf8.size()),
            &written, nullptr);
  CloseHandle(pipe);
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
        _In_ wchar_t* command_line, _In_ int show_command) {
  std::wstring openedFilePath;
  int argc = 0;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv && argc >= 2) {
    openedFilePath = argv[1];
    LocalFree(argv);
  }

  HANDLE mutex = CreateMutexW(nullptr, TRUE,
                              L"au.com.sharpblue.inkworm.single");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    if (!openedFilePath.empty()) {
      ForwardToExistingInstance(openedFilePath);
    }
    CloseHandle(mutex);
    return 0;
  }

  if (!openedFilePath.empty()) {
    g_opened_file_path = WideToUtf8(openedFilePath);
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"inkworm", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
