#!/bin/bash

##
# twgit
#
#
#
# Copyright (c) 2011 Twenga SA
# Copyright (c) 2012 Geoffroy Aubry <geoffroy.aubry@free.fr>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
# for the specific language governing permissions and limitations under the License.
#
# @copyright 2011 Twenga SA
# @copyright 2012 Geoffroy Aubry <geoffroy.aubry@free.fr>
# @license http://www.apache.org/licenses/LICENSE-2.0
#



##
# Affiche l'aide de la commande tag.
#
# @testedby TwgitHelpTest
#
function usage () {
    echo; CUI_displayMsg help 'Usage:'
    CUI_displayMsg help_detail '<b>twgit release <action></b>'
    echo; CUI_displayMsg help 'Available actions are:'
    CUI_displayMsg help_detail '<b>committers [<max>] [-F]</b>'
    CUI_displayMsg help_detail '    List first <b><max></b> committers into the current release.'
    CUI_displayMsg help_detail "    Default value of <b><max></b>: $TWGIT_DEFAULT_NB_COMMITTERS. Add <b>-F</b> to do not make fetch."; echo
    CUI_displayMsg help_detail '<b>list [-F]</b>'
    CUI_displayMsg help_detail '    List remote releases. Add <b>-F</b> to do not make fetch.'; echo
    CUI_displayMsg help_detail '<b>finish [<tagname>] [-I]</b>'
    CUI_displayMsg help_detail "    Merge current release branch into '$TWGIT_STABLE', create a new tag and push."
    CUI_displayMsg help_detail '    If no <b><tagname></b> is specified then current release name will be used.'
    CUI_displayMsg help_detail '    Add <b>-I</b> to run in non-interactive mode (always say yes).'; echo
    CUI_displayMsg help_detail '<b>remove <releasename></b>'
    CUI_displayMsg help_detail '    Remove both local and remote specified release branch.'
    CUI_displayMsg help_detail '    Despite that, create the same tag as finish action to clearly distinguish'
    CUI_displayMsg help_detail '    the next release from this one.'; echo
    CUI_displayMsg help_detail '<b>reset <releasename> [-I|-M|-m]</b>'
    CUI_displayMsg help_detail '    Call <b>twgit remove <releasename></b>, then <b>twgit start [-I|-M|-m]</b>.'
    CUI_displayMsg help_detail '    Handle options of <b>twgit start</b>.'; echo
    CUI_displayMsg help_detail '<b>start [<releasename>] [-I|-M|-m]</b>'
    CUI_displayMsg help_detail '    Create both a new local and remote release, or fetch the remote release,'
    CUI_displayMsg help_detail '    or checkout the local release. Add <b>-I</b> to run in non-interactive mode'
    CUI_displayMsg help_detail '    (always say yes). If no <b><releasename></b> is specified, a name will be'
    CUI_displayMsg help_detail '    generated by incrementing the last tag (e.g. v1.2.3):'
    CUI_displayMsg help_detail "        <b>-M</b> for a new major version (> ${TWGIT_PREFIX_RELEASE}2.0.0)"
    CUI_displayMsg help_detail "        <b>-m</b> for a new minor version (default, > ${TWGIT_PREFIX_RELEASE}1.3.0)"; echo
    CUI_displayMsg help_detail "Prefix '$TWGIT_PREFIX_RELEASE' will be added to <b><releasename></b> parameters."
    CUI_displayMsg help_detail "Prefix '$TWGIT_PREFIX_TAG' will be added to <b><tagname></b> parameters."; echo
    CUI_displayMsg help_detail '<b>[help]</b>'
    CUI_displayMsg help_detail '    Display this help.'; echo
}

##
# Action déclenchant l'affichage de l'aide.
#
# @testedby TwgitHelpTest
#
function cmd_help () {
    usage;
}

##
# Liste les personnes ayant le plus committé sur l'éventuelle release en cours.
# Gère l'option '-F' permettant d'éviter le fetch.
#
# @param int $1 nombre de committers à afficher au maximum, optionnel
#
function cmd_committers () {
    process_options "$@"
    require_parameter '-'
    local max="$RETVAL"
    process_fetch 'F'

    local branch_fullname="$(get_current_release_in_progress)"
    [ -z "$branch_fullname" ] && die 'No release in progress!'

    display_rank_contributors "$branch_fullname" "$max"
}

##
# Liste les releases ainsi que leurs éventuelles features associées.
# Gère l'option '-F' permettant d'éviter le fetch.
#
function cmd_list () {
    process_options "$@"
    process_fetch 'F'

    local releases=$(git branch -r --merged $TWGIT_ORIGIN/$TWGIT_STABLE | grep "$TWGIT_ORIGIN/$TWGIT_PREFIX_RELEASE" | sed 's/^[* ]*//')
    if [ ! -z "$releases" ]; then
        CUI_displayMsg help "Remote releases merged into '<b>$TWGIT_STABLE</b>':"
        CUI_displayMsg warning "A release must be deleted after merge into '<b>$TWGIT_STABLE</b>'! Following releases should not exists!"
        display_branches 'release' "$releases"
        echo
    fi

    local release="$(get_current_release_in_progress)"
    CUI_displayMsg help "Remote release NOT merged into '<b>$TWGIT_STABLE</b>':"
    if [ ! -z "$release" ]; then
        display_branches 'release' "$TWGIT_ORIGIN/$release" # | head -n -1
        CUI_displayMsg info 'Features:'

        get_merged_features $release
        local merged_features="$GET_MERGED_FEATURES_RETURN_VALUE"

        local prefix="$TWGIT_ORIGIN/$TWGIT_PREFIX_FEATURE"
        for f in $merged_features; do
            echo -n "    - $f "
            echo -n $(CUI_displayMsg ok '[merged]')' '
            displayFeatureSubject "${f:${#prefix}}"
        done

        get_features merged_in_progress $release
        local merged_in_progress_features="$GET_FEATURES_RETURN_VALUE"

        for f in $merged_in_progress_features; do
            echo -n "    - $f ";
            echo -n $(CUI_displayMsg warning 'merged, then in progress.')' '
            displayFeatureSubject "${f:${#prefix}}"
        done
        if [ -z "$merged_features" ] && [ -z "$merged_in_progress_features" ]; then
            CUI_displayMsg info '    - No such branch exists.'
        fi
    else
        display_branches 'release' ''
    fi
    echo

    alert_dissident_branches
}

##
# Crée une nouvelle release à partir du dernier tag.
# Si le nom n'est pas spécifié, un nom sera généré automatiquement à partir du dernier tag
# en incrémentant par défaut d'une version mineure. Ce comportement est modifiable via les
# options -M (major) ou -m (minor).
# Rappel : une version c'est major.minor.revision
# Gère l'option '-I' permettant de répondre automatiquement (mode non interactif) oui à la vérification de version.
#
# @param string $1 nom court optionnel de la nouvelle release.
#
function cmd_start () {
    process_options "$@"
    require_parameter '-'
    local release="$RETVAL"
    local release_fullname

    assert_clean_working_tree
    process_fetch
    assert_tag_exists

    local current_release=$(get_current_release_in_progress)
    current_release="${current_release:${#TWGIT_PREFIX_RELEASE}}"

    if [ -z $release ]; then
        if [ ! -z "$current_release" ]; then
            release="$current_release"
        else
            local type
            isset_option 'M' && type='major' || type='minor'
            release=$(get_next_version $type)
            echo "Release: $TWGIT_PREFIX_RELEASE$release"
            if ! isset_option 'I'; then
                echo -n $(CUI_displayMsg question 'Do you want to continue? [Y/N] '); read answer
                [ "$answer" != "Y" ] && [ "$answer" != "y" ] && die 'New release aborted!'
            fi
        fi
    fi

    assert_valid_ref_name $release
    release_fullname="$TWGIT_PREFIX_RELEASE$release"

    if [ ! -z "$current_release" ]; then
        if [ "$current_release" != "$release" ]; then
            die "No more one release is authorized at the same time! Try: \"twgit release list\" or \"twgit release start $current_release\""
        else
            assert_new_local_branch $release_fullname
            exec_git_command "git checkout --track -b $release_fullname $TWGIT_ORIGIN/$release_fullname" "Could not check out release '$TWGIT_ORIGIN/$release_fullname'!"
        fi
    else
        local last_tag=$(get_last_tag)
        exec_git_command "git checkout -b $release_fullname tags/$last_tag" "Could not check out tag '$last_tag'!"
        process_first_commit 'release' "$release_fullname"
        process_push_branch $release_fullname
    fi

    alert_old_branch $TWGIT_ORIGIN/$release_fullname with-help
    echo
}

##
# Merge la release à la branche stable et crée un tag portant son nom s'il est compatible (major.minor.revision)
# ou récupère celui spécifié en paramètre.
# Gère l'option '-I' permettant de répondre automatiquement (mode non interactif) oui à la demande de pull.
#
# @param string $1 nom court optionnel du tag
#
function cmd_finish () {
    process_options "$@"
    require_parameter '-'
    local tag="$RETVAL"

    assert_clean_working_tree
    process_fetch

    # Récupération de la release en cours :
    CUI_displayMsg processing 'Check remote release...'
    local release_fullname="$(get_current_release_in_progress)"
    [ -z "$release_fullname" ] && die 'No release in progress!'
    local release="${release_fullname:${#TWGIT_PREFIX_RELEASE}}"
    CUI_displayMsg processing "Remote release '$release_fullname' detected."

    # Gestion du tag :
    [ -z "$tag" ] && tag="$release"
    local tag_fullname="$TWGIT_PREFIX_TAG$tag"
    assert_new_and_valid_tag_name $tag

    # Détection hotfixes en cours :
    CUI_displayMsg processing 'Check hotfix in progress...'
    local hotfix="$(get_hotfixes_in_progress)"
    [ ! -z "$hotfix" ] && die "Close a release while hotfix in progress is forbidden! Hotfix '$hotfix' must be treated first."

    # Détection tags (via hotfixes) réalisés entre temps :
    CUI_displayMsg processing 'Check tags not merged...'
    get_tags_not_merged_into_branch "$TWGIT_ORIGIN/$release_fullname"
    tags_not_merged="$(echo "$GET_TAGS_NOT_MERGED_INTO_BRANCH_RETURN_VALUE" | sed 's/ /, /g')"

    [ ! -z "$tags_not_merged" ] && die "You must merge following tag(s) into this release before close it: $tags_not_merged"

    CUI_displayMsg processing 'Check remote features...'
    get_features merged_in_progress $release_fullname
    local features="$GET_FEATURES_RETURN_VALUE"

    [ ! -z "$features" ] && die "Features exists that are merged into this release but yet in development: $(echo $features | sed 's/ /, /g')!"

    CUI_displayMsg processing "Check local branch '$release_fullname'..."
    if has $release_fullname $(get_local_branches); then
        assert_branches_equal "$release_fullname" "$TWGIT_ORIGIN/$release_fullname"
    else
        exec_git_command "git checkout --track -b $release_fullname $TWGIT_ORIGIN/$release_fullname" "Could not check out hotfix '$TWGIT_ORIGIN/$hotfix_fullname'!"
    fi

    assert_clean_stable_branch_and_checkout
    exec_git_command "git merge --no-ff $release_fullname" "Could not merge '$release_fullname' into '$TWGIT_STABLE'!"

    # Get all included features:
    get_merged_features $release_fullname
    local features="$GET_MERGED_FEATURES_RETURN_VALUE"
    local prefix="$TWGIT_ORIGIN/$TWGIT_PREFIX_FEATURE"

    # Tag generation:
    tag_comment="Release finish: $release_fullname"
    for feature in $features; do
        local feature_shortname="${feature:${#prefix}}"
        local subject="$(getFeatureSubject "$feature_shortname")"
        [ ! -z "$subject" ] && subject=": \"$subject\""
        tag_comment="$tag_comment\n${TWGIT_PREFIX_COMMIT_MSG}Contains $TWGIT_PREFIX_FEATURE$feature_shortname$subject"
    done
    tag_comment="$(echo -e "$tag_comment")"
    create_and_push_tag "$tag_fullname" "$tag_comment"

    # Suppression des features associées :
    for feature in $features; do
        CUI_displayMsg processing "Delete '$feature' feature..."
        remove_feature "${feature:${#prefix}}"
    done

    # Suppression de la branche :
    remove_local_branch $release_fullname
    remove_remote_branch $release_fullname
    echo
}

##
# Supprime la release spécifiée.
#
# @param string $1 nom court de la release
#
function cmd_remove () {
    process_options "$@"
    require_parameter 'release'
    local release="$RETVAL"
    local release_fullname="$TWGIT_PREFIX_RELEASE$release"
    local tag="$release"
    local tag_fullname="$TWGIT_PREFIX_TAG$tag"

    assert_valid_ref_name $release
    assert_clean_working_tree

    process_fetch
    assert_new_and_valid_tag_name $tag

    # Suppression de la branche :
    assert_clean_stable_branch_and_checkout
    remove_local_branch $release_fullname
    remove_remote_branch $release_fullname

    # Gestion du tag :
    create_and_push_tag "$tag_fullname" "Release remove: $release_fullname"
    echo
}

##
# Supprime la release spécifiée et en recrée une nouvelle.
# Pour se sortir des releases non viables.
# Appelle "twgit remove <releasename>" suivi de "twgit start".
# Gère les options '-IMm' de twgit release start.
#
# @param string $1 nom court de la release à supprimer
# @testedby TwgitReleaseTest
#
function cmd_reset () {
    process_options "$@"
    require_parameter 'release'
    local release="$RETVAL"

    cmd_remove "$release" && cmd_start
}
