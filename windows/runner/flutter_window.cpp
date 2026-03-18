#include "flutter_window.h"
#include "file_channel.h"

#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <optional>
#include <thread>
#include <string>

#include "flutter/generated_plugin_registrant.h"

// Custom window message posted from the pipe thread to the main thread.
// LPARAM will be a heap-allocated std::string* we must delete after use.
static constexpr UINT WM_FILE_OPENED = WM_APP + 1;

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Register the file-open method channel. Store in member so it stays alive.
  file_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
                  "au.com.sharpblue.inkworm/file",
                  &flutter::StandardMethodCodec::GetInstance());

  file_channel_->SetMethodCallHandler(
          [](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
              if (call.method_name() == "getOpenedFile") {
                if (!g_opened_file_path.empty()) {
                  result->Success(flutter::EncodableValue(g_opened_file_path));
                } else {
                  result->Success(flutter::EncodableValue());  // null
                }
              } else {
                result->NotImplemented();
              }
          });

  // Start the named-pipe listener. Posts WM_FILE_OPENED to this window's
  // HWND when a second instance forwards a path to us.
  HWND hwnd = GetHandle();
  pipe_running_ = true;
  pipe_thread_ = std::thread([this, hwnd]() {
      while (pipe_running_) {
        HANDLE pipe = CreateNamedPipeW(
                kPipeName,
                PIPE_ACCESS_INBOUND,
                PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
                1, 0, 4096, NMPWAIT_USE_DEFAULT_WAIT, nullptr);
        if (pipe == INVALID_HANDLE_VALUE) break;

        if (ConnectNamedPipe(pipe, nullptr) ||
            GetLastError() == ERROR_PIPE_CONNECTED) {
          char buf[4096] = {};
          DWORD bytesRead = 0;
          if (ReadFile(pipe, buf, sizeof(buf) - 1, &bytesRead, nullptr) &&
              bytesRead > 0) {
            // Heap-allocate the path; MessageHandler will delete it.
            auto* path = new std::string(buf, bytesRead);
            PostMessage(hwnd, WM_FILE_OPENED, 0,
                        reinterpret_cast<LPARAM>(path));
          }
        }
        CloseHandle(pipe);
      }
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
      this->Show();
  });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  pipe_running_ = false;
  // Unblock the pipe thread if it's waiting for a connection.
  HANDLE wake = CreateFileW(kPipeName, GENERIC_WRITE, 0, nullptr,
                            OPEN_EXISTING, 0, nullptr);
  if (wake != INVALID_HANDLE_VALUE) CloseHandle(wake);
  if (pipe_thread_.joinable()) pipe_thread_.join();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
    if (message == WM_FILE_OPENED) {
    // Reclaim the heap-allocated path posted by the pipe thread.
        auto* path = reinterpret_cast<std::string*>(lparam);
        if (path && !path->empty() && file_channel_) {
            file_channel_->InvokeMethod(
                "fileOpened",
                std::make_unique<flutter::EncodableValue>(*path));
        }
        delete path;
        return 0;
    }

    if (flutter_controller_) {
        std::optional<LRESULT> result =
                flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                              lparam);
        if (result) {
            return *result;
        }
    }

    switch (message) {
        case WM_FONTCHANGE:
            flutter_controller_->engine()->ReloadSystemFonts();
            break;
    }

    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}