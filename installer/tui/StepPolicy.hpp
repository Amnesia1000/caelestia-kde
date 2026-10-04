#pragma once

#include <string>
#include <unordered_map>

namespace StepPolicy {
bool is_skipped(const std::string& step_name,
                const std::unordered_map<std::string, std::string>& answers);
}