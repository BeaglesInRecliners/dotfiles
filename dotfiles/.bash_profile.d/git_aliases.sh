# Bunch of git command shortcuts
gs() { git status -sb; }
gits() { git status -sb; }
gc() { git clean -dxf; }
gitclean() { git clean -dxf; }
gitdiff() { git difftool -y --tool=vimdiff "$1"; }
gitpatch() { git diff --no-ext-diff -w "$@" | vim -R -; }
gitcm() { git commit -m "$@"; }
gitba() { git branch -a "$@"; }
gitbl() { git branch -l "$@"; }
gitcount() { git rev-list HEAD --count; }
gitlog() { git log --no-merges "$@"; }
pushme() { 
  REMOTE=$( git for-each-ref --format='%(upstream:short)' $( git symbolic-ref -q HEAD ) | awk -F'/' '{print $1}' )
  BRANCH=$( git rev-parse --abbrev-ref HEAD )
  git push $REMOTE $BRANCH
}

# Switch to the git root directory
gitroot() { cd $(git rev-parse --show-toplevel); }

# Show a deleted file
gitshowdeleted() { 
  if [ "$#" -eq 0 ]; then
    git log --diff-filter=D --summary | grep delete; 
  else
    git log --diff-filter=D --summary | grep delete | grep $@;
  fi
}
gitsd() { gitshowdeleted $@; }

# Get the second to last commit of a deleted file.
# The last commit is actually deleting the file, so you can apply it,
#   so apply the second to last commit.
gitgetdeleted() {
  WD=$( pwd )
  gitroot;
  SHA=$( gitlc $1 1 )
  git checkout ${SHA} -- $1
  cd ${WD};
}
gitgd() { gitgetdeleted $@; }


# Get the SHA list of when a file was modified.
gitfilecommit() {
  WD=$( pwd );
  gitroot;
  git log --pretty=oneline --all -- $@;
  cd ${WD};
}
gitfc() { gitfilecommit $@; }

# Find the last (or nth to last) commit of a file
gitlastcommit() { 
  if [ "$#" -eq 1 ]; then
    gitfilecommit $1 | head -n 1 | awk -F' ' '{print $1}';
  elif [ "$#" -eq 2 ]; then
    let "CNT=$2 + 1"
    gitfilecommit $1 | head -n ${CNT} | tail -n 1 | awk -F' ' '{print $1}';
  else
    echo "Gets the last (or nth to last) commit that a file was changed"
    echo " Usage: gitlastcommit <file_path> [num_commits_from_end]"
    return
  fi
}
gitlc() { gitlastcommit $@; }


# Do a vimdiff git conflict merging
gitconflict() { vim $(git status -s | grep ^UU | cut -f 2 -d ' '); }
alias gitcon='gitconflict'

# Do a bit of git history filtering
githist() {
  if [ "$#" -eq 1 ]; then
    git hist | grep -i $1 | grep -v "Merge" | less -RS;
  else
    git hist;
  fi
}

# Get the SHA value of the first commit on a branch
gitstart() {
  if [ "$#" -gt 2 ] || [ "$1" = "-h" ]; then
    echo "Gets the inital commit of a branch"
    echo " Usage: gitstart [<source_branch>] [<parent_branch>]"
    echo " Usage: gitstart -h"
    return
  fi

  if [ "$#" -eq 2 ]; then
    SRC=$1
    PARENT=$2
    git rev-list --boundary $(git rev-parse --abbrev-ref ${SRC})...${PARENT} | grep ^- | cut -c2- | head -1
  else
    SRC=$1
    git log --pretty=format:'[%H %P] %s' ${SRC} | grep -o -P '(?<=\[).*(?=\])' | grep -o -P ".{0,40} .{0,40} .{0,40}" -m 1 | awk -F' ' '{print $1}'
  fi
}

# Get the SHA value of the last commit on a branch
gitend() {
  if [ "$#" -gt 0 ] && [ "$1" = "-h" ]; then
    echo "Gets the last commit of a branch"
    echo " Usage: gitend [<source_branch>]"
    echo " Usage: gitend -h"
    return
  fi

  if [ "$#" -eq 1 ]; then
    # Load the incoming branch name filter
    NAME="$1"
  else
    # Use the current Git repo branch name
    NAME=`git branch | grep '*' | awk -F' ' '{print $2}'`
  fi

  SHA=`git for-each-ref | grep ${NAME} | awk -F' ' '{print $1}' | uniq`
  if [ `echo -e ${SHA} | wc -w` -gt 1 ]; then
    echo "Too many branch matches."
    echo -e "`git for-each-ref | grep ${NAME}`"
    echo -e "\nUsage: gitsha <unique_branch_name>"
  else 
    echo ${SHA}
  fi
}

# Attempt to cherry-pick and entire branch by supplying the branch name and not the SHA
gitpick() {
  if [ "$#" -gt 2 ] || [ "$#" -lt 1 ] || [ "$1" = "-h" ]; then
    echo "Gets the start/end commits of a branch and performs a 'git cherry-pick'"
    echo "It is recommended to perform a 'git checkout -b <branch_name> before executing this command"
    echo " Usage: gitpick <source_branch> [<parent_branch>]"
    echo " Usage: gitpick -h"
    return
  fi

  # Load the incoming branch names
  SRC="$1"
  PARENT="$2"
  # Get the SHA commit hashes
  START=`gitstart ${SRC} ${PARENT}`
  END=`gitend ${SRC}`

  git cherry-pick ${START}..${END}
}


# Get the size of the largest files in the history
git_size() {
  # http://stubbisms.wordpress.com/2009/07/10/git-script-to-show-largest-pack-objects-and-trim-your-waist-line/
  
  # Search up the tree for the .git directory
  path=""
  i=0
  while [ $i -lt 20 ] && [ `find $path -type d | grep .git | wc -l` -eq 0 ]; do
    path+="../"
    let i+=1
  done

  # set the internal field spereator to line break, so that we can iterate easily over the verify-pack output
  IFS=$'\n';
   
  # list all objects including their size, sort by size
  objects=`git verify-pack -v $path.git/objects/pack/pack-*.idx | grep -v chain | sort -k3nr | head -n $1 | tr -s ' '`
  echo "All sizes are in kB's. The pack column is the size of the object, compressed, inside the pack file."
  output="size,pack,SHA,location"

  for y in $objects
  do
    # extract the size in bytes
    size=$((`echo $y | cut -f 3 -d ' '`/1024))
    # extract the compressed size in bytes
    compressedSize=$((`echo $y | cut -f 4 -d ' '`/1024))
    # extract the SHA
    sha=`echo $y | cut -f 1 -d ' '`
    # find the objects location in the repository tree
    sha_and_file=`git rev-list --all --objects | grep $sha | sed -r 's/ /,/g'`
    #lineBreak=cho -e "\n"
    output="${output}\n${size},${compressedSize},${sha_and_file}"
  done
   
  echo -e $output | column -t -s ','
}

# Run the git_size command, but do some filtering
gitsize() {
  if [ "$#" -ne 1 ]; then
    git_size 10;
  else
    git_size $1
  fi
}

