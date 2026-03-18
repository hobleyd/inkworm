#ifndef RUNNER_FILE_CHANNEL_H_
#define RUNNER_FILE_CHANNEL_H_

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

static constexpr wchar_t kPipeName[] =
        L"\\\\.\\pipe\\au.com.sharpblue.inkworm";

// Filled in by main.cpp before the window is created.
extern std::string g_opened_file_path;

inline std::string WideToUtf8(const std::wstring& wide) {
    if (wide.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                   static_cast<int>(wide.size()),
                                   nullptr, 0, nullptr, nullptr);
    std::string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                        static_cast<int>(wide.size()),
                        result.data(), size, nullptr, nullptr);
    return result;
}

#endif  // RUNNER_FILE_CHANNEL_H_
