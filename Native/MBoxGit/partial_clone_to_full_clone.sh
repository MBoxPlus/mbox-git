#!/bin/sh

#  partial_clone_to_full_clone.sh
#  MBoxGit
#
#  Created by 詹迟晶 on 2022/5/23.
#  Copyright © 2022 com.bytedance. All rights reserved.

set -e

function notify() {
    osascript -e "display notification \"$2\" with title \"$1\""
}

url=$(git remote get-url origin)

notify "MBox Downloading ..." "${url}"

git fetch-pack --refetch --all ${url}

git config --local --unset remote.origin.promisor
git config --local --unset remote.origin.partialclonefilter
git config --local --int core.repositoryformatversion 0

notify "MBox Download Complete!" "${url}"
