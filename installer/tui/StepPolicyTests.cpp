#include "StepPolicy.hpp"

#include <cassert>
#include <map>
#include <string>

int main() {
    using Answers = std::map<std::string, std::string>;

    assert(StepPolicy::is_skipped("Update system", {{"SKIP_SYSTEM_UPDATE", "true"}}));
    assert(!StepPolicy::is_skipped("Update system", {{"SKIP_SYSTEM_UPDATE", "false"}}));
    assert(StepPolicy::is_skipped("Install SDDM theme", Answers{}));
    assert(!StepPolicy::is_skipped("Install SDDM theme", {{"INSTALL_SDDM", "true"}}));
    assert(StepPolicy::is_skipped("Install optional components", Answers{}));
    assert(!StepPolicy::is_skipped("Install optional components", {{"INSTALL_ZED", "true"}}));
    assert(!StepPolicy::is_skipped("Build Caelestia shell", Answers{}));
    return 0;
}