
USING: accessors calendar combinators.cleave
combinators.short-circuit concurrency.combinators destructors
fry io io.directories io.encodings io.encodings.utf8
io.launcher io.monitors io.pathnames io.pipes io.ports kernel
locals math namespaces sequences splitting strings system
threads ui ui.gadgets ui.gadgets.buttons ui.gadgets.editors
ui.gadgets.labels ui.gadgets.packs ui.gadgets.tracks ;

IN: git-tool

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: head** ( seq obj -- seq/f ) dup number? [ head ] [ dupd find drop head ] if ;

: tail** ( seq obj -- seq/f )
  dup number?
    [ tail ]
    [ dupd find drop [ tail ] [ drop f ] if* ]
  if ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: <process-stdout-stderr-reader> ( DESC -- process stream stream )
  [
    [let | STDOUT-PIPE [ (pipe) |dispose ]
           STDERR-PIPE [ (pipe) |dispose ] |

      [let | PROCESS [ DESC >process ] |

        PROCESS
          [ STDOUT-PIPE out>> or ] change-stdout
          [ STDERR-PIPE out>> or ] change-stderr
        run-detached

        STDOUT-PIPE out>> dispose
        STDERR-PIPE out>> dispose

        STDOUT-PIPE in>> <input-port> utf8 <decoder>
        STDERR-PIPE in>> <input-port> utf8 <decoder> ] ]
  ]
  with-destructors ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: run-process/result ( desc -- process )
  <process-stdout-stderr-reader>
  {
    [ contents [ string-lines ] [ f ] if* ]
    [ contents [ string-lines ] [ f ] if* ]
  }
  parallel-spread
  [ >>stdout ] [ >>stderr ] bi*
  dup wait-for-process >>status ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! process popup windows
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: popup-window ( title contents -- )
  dup string? [ ] [ "\n" join ] if
  <editor> tuck set-editor-string swap open-window ;

: popup-process-window ( process -- )
  [ stdout>> [ "output" swap popup-window ] when* ]
  [ stderr>> [ "error"  swap popup-window ] when* ]
  [
    [ stdout>> ] [ stderr>> ] bi or not
    [ "Process" "NO OUTPUT" popup-window ]
    when
  ]
  tri ;

: popup-if-error ( process -- )
  { [ status>> 0 = not ] [ popup-process-window t ] } 1&& drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-process ( REPO DESC -- process )
  REPO [ DESC run-process/result ] with-directory ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: git-status-section ( lines section -- lines/f )
  '[ _ = ] tail**
    [
      [ "#\t" head?      ] tail**
      [ "#\t" head?  not ] head**
      [ 2 tail ] map
    ]
    [ f ]
  if* ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: colon ( -- ch ) CHAR: : ;
: space ( -- ch ) 32      ;

: git-status-line-file ( line -- file )
  { [ colon = ] 1 [ space = not ] } [ tail** ] each ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: check-empty ( seq -- seq/f ) dup empty? [ drop f ] when ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-status-gadget> < pack

  repository

  to-commit-new
  to-commit-modified
  to-commit-deleted
  modified
  deleted
  untracked

  closed
  
  last-refresh ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M:: <git-status-gadget> ungraft* ( GADGET -- ) GADGET t >>closed drop ;
  
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-status ( GADGET -- )

 [let | LINES [ GADGET repository>> { "git" "status" } git-process stdout>> ] |

    GADGET
    
      LINES "# Changes to be committed:" git-status-section
        [ "new file:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-new
    
      LINES "# Changes to be committed:" git-status-section
        [ "modified:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-modified

      LINES "# Changes to be committed:" git-status-section
        [ "deleted:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>to-commit-deleted

      LINES "# Changed but not updated:" git-status-section
        [ "modified:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>modified
    
      LINES "# Changed but not updated:" git-status-section
        [ "deleted:" head? ] filter
        [ git-status-line-file ] map
        check-empty
      >>deleted

      LINES "# Untracked files:" git-status-section >>untracked ]

  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: to-commit ( <git-status> -- seq )
  { to-commit-new>> to-commit-modified>> to-commit-deleted>> } 1arr concat ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-git-status-gadget ( GADGET -- )

  GADGET refresh-status

  GADGET clear-gadget

  GADGET

  ! Commit section

  [wlet | add-commit-path-button [| TEXT PATH |

            { 1 0 } <track>

              TEXT <label> 2/8 track-add
              PATH <label> 6/8 track-add

              "Reset"
              [
                drop
                
                GADGET repository>>
                { "git" "reset" "HEAD" PATH }
                git-process
                drop
                
                GADGET refresh-git-status-gadget
              ]
              <bevel-button> f track-add

            add-gadget ] |

    GADGET to-commit
    [
      "Changes to be committed" <label> reverse-video-theme add-gadget

      GADGET to-commit-new>>
      [| PATH | "new file: " PATH add-commit-path-button ]
      each

      GADGET to-commit-modified>>
      [| PATH | "modified: " PATH add-commit-path-button ]
      each

      GADGET to-commit-deleted>>
      [| PATH | "deleted: " PATH add-commit-path-button ]
      each

      <pile> 1 >>fill

        [let | EDITOR [ <editor> "COMMIT MESSAGE" over set-editor-string ] |

          EDITOR add-gadget
  
          "Commit"
          [
           drop
           [let | MSG [ EDITOR editor-string ] |

              GADGET repository>>
              { "git" "commit" "-m" MSG } git-process
              popup-if-error ]
           GADGET refresh-git-status-gadget
          ]
          <bevel-button>
          add-gadget ]
       
      add-gadget

    ]
    when ]

  ! Modified section

  GADGET modified>>
  [
    "Modified but not updated" <label> reverse-video-theme add-gadget

    GADGET modified>>
    [| PATH |

      <shelf>

        PATH <label> add-gadget

        "Add"
        [
          drop
          GADGET repository>> { "git" "add" PATH } git-process popup-if-error
          GADGET refresh-git-status-gadget
        ]
        <bevel-button> add-gadget

        "Diff"
        [
          drop
          GADGET repository>> { "git" "diff" PATH } git-process
          popup-process-window
        ]
        <bevel-button> add-gadget

      add-gadget
      
    ]
    each
    
  ]
  when

  ! Untracked section

  GADGET untracked>>
  [
    "Untracked files" <label> reverse-video-theme add-gadget

    GADGET untracked>>
    [| PATH |

      { 1 0 } <track>

        PATH <label> f track-add

        "Add"
        [
          drop
          GADGET repository>> { "git" "add" PATH } git-process popup-if-error
          GADGET refresh-git-status-gadget
        ]
        <bevel-button> f track-add

      add-gadget

    ]
    each
    
  ]
  when

  drop ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: start-monitor-thread ( GADGET -- )

  GADGET f >>closed drop

  [
    [
      [let | MONITOR [ GADGET repository>> t <monitor> ] |
        
        [
          GADGET closed>>
          [ f ]
          [
            [let | PATH [ MONITOR next-change drop ] |

              ".git" PATH subseq?
              [ ]
              [
                micros GADGET last-refresh>> 0 or -
                1000000 >
                [
                  GADGET micros >>last-refresh drop
                  GADGET refresh-git-status-gadget
                ]
                when
              ]
              if ]

            t

          ]
          if
        ]
        loop
      ]
    ]
    with-monitors
  ]
  in-thread ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M:: <git-status-gadget> graft* ( GADGET -- ) GADGET start-monitor-thread ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-status-gadget ( REPO -- gadget )

  <git-status-gadget> new-gadget

  { 0 1 } >>orientation

  1 >>fill

  REPO >>repository

  dup refresh-git-status-gadget ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! remotes
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: current-branch ( REPO -- branch )
  { "git" "branch" } git-process stdout>> [ "* " head? ] find nip 2 tail ;

: list-branches ( REPO -- branches )
  { "git" "branch" } git-process stdout>>
  [ empty? not ] filter
  [ 2 tail ] map ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: list-remotes ( REPO -- remotes )
  { "git" "remote" } git-process stdout>> [ empty? not ] filter ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: list-remote-branches ( REPO REMOTE -- branches )
  [let | OUT [ REPO { "git" "remote" "show" REMOTE } git-process stdout>> ] |

    "  Tracked remote branches" OUT member?
      [
        OUT
        "  Tracked remote branches" OUT index 1 + tail first " " split
        [ empty? not ] filter
      ]
      [
        OUT
        OUT [ "  New remote branches" head? ] find drop
        1 + tail first " " split
        [ empty? not ] filter
      ]
    if ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-remote-track> < track repository remote remote-branch ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-git-remote-track ( GADGET -- )

  [let | REPO [ GADGET repository>> ] |

    GADGET clear-gadget

    GADGET sizes>> delete-all

    GADGET

    ! Remote button

    GADGET remote>>
      [
        drop

        <pile>

          1 >>fill

          REPO list-remotes

            [| REMOTE |

              REMOTE
                [
                  drop
                  GADGET REMOTE   >>remote        drop
                  GADGET "master" >>remote-branch drop
                  GADGET refresh-git-remote-track
                ]
              <bevel-button> add-gadget

            ]
        
          each

        "Select a remote" open-window
      
      ]
    <bevel-button> 1/6 track-add

    ! Remote branch button

    GADGET remote-branch>>
    [
      drop

      <pile>

      1 >>fill

      REPO GADGET remote>> list-remote-branches

      [| REMOTE-BRANCH |

        REMOTE-BRANCH
        [
          drop
          GADGET REMOTE-BRANCH >>remote-branch drop
          GADGET refresh-git-remote-track
        ]
        <bevel-button> add-gadget
      ]
      
      each

      "Select a remote branch" open-window

    ]
    <bevel-button> 1/6 track-add

    ! Fetch button

    "Fetch"
    [
      drop
      [let | REMOTE [ GADGET remote>> ] |
        REPO { "git" "fetch" REMOTE } git-process popup-if-error ]
      
      GADGET refresh-git-remote-track
    ]
    <bevel-button> f track-add

    ! Available changes

    [let | REMOTE        [ GADGET remote>>        ]
           REMOTE-BRANCH [ GADGET remote-branch>> ] |

      [let | ARG [ { ".." REMOTE "/" REMOTE-BRANCH } concat ] |

        [let | PROCESS [ REPO { "git" "log" ARG } git-process ] |

          PROCESS stdout>>
            [

              "Mergable"
              [ drop PROCESS popup-process-window ]
              <bevel-button> 1/6 track-add

              "Merge"
              [
                drop

                [let | ARG [ { REMOTE "/" REMOTE-BRANCH } concat ] |

                  REPO { "git" "merge" ARG } git-process popup-process-window

                ]

                GADGET refresh-git-remote-track

              ]
              <bevel-button> 1/6 track-add

            ]
            [
              "" <label> 1/6 track-add
              "" <label> 1/6 track-add
            ]
          if

        ] ] ]

    ! Pushable changes

    [let | REMOTE        [ GADGET remote>>        ]
           REMOTE-BRANCH [ GADGET remote-branch>> ] |

      [let | ARG [ { REMOTE "/" REMOTE-BRANCH ".." } concat ] |

        [let | PROCESS [ REPO { "git" "log" ARG } git-process ] |

          PROCESS stdout>>
            [
                "Pushable"
                [ drop PROCESS popup-process-window ]
                <bevel-button> 1/6 track-add

                "Push"
                [
                  drop

                  REPO { "git" "push" REMOTE REMOTE-BRANCH }
                  git-process
                  popup-process-window

                  GADGET refresh-git-remote-track

                ]
                <bevel-button> 1/6 track-add

            ]
            [
              "" <label> 1/6 track-add
              "" <label> 1/6 track-add
            ]
          if
          
        ] ] ]

    drop ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-remote-track ( REPO -- gadget )

  <git-remote-track> new

    init-track

    { 1 0 } >>orientation

    REPO >>repository

    "origin" >>remote

    "master" >>remote-branch

    dup refresh-git-remote-track ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! <git-remotes-gadget>
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-remotes-gadget> < pack repository closed last-refresh ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-remotes-gadget ( REPO -- gadget )

  <git-remotes-gadget> new-gadget

    { 0 1 } >>orientation

    1 >>fill

    REPO >>repository

    "Remotes" <label> reverse-video-theme add-gadget

    REPO list-remotes

      [| REMOTE |

        REPO git-remote-track
          REMOTE >>remote
          dup refresh-git-remote-track
        add-gadget

      ]
    each ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: refresh-git-remotes-gadget ( GADGET -- )
  
  GADGET children>> [ <git-remote-track>? ] filter
    [ refresh-git-remote-track ]
  each ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! :: start-remotes-monitor-thread ( GADGET -- )

!   GADGET f >>closed drop

!   [
!     [
!       [let | MONITOR [ GADGET repository>> t <monitor> ] |
        
!         [
!           GADGET closed>>
!             [ f ]
!             [
!               [let | PATH [ MONITOR next-change drop ] |

!                 micros  GADGET last-refresh>> 0 or  -    1000000 >
!                   [

!                     GADGET micros >>last-refresh drop

!                     ! "FETCH_HEAD"     PATH subseq?
!                     ! "COMMIT_EDITMSG" PATH subseq? or

!                     "COMMIT_EDITMSG" PATH subseq?
!                       [ GADGET refresh-git-remotes-gadget ]
!                     when

!                   ]
!                 when ]
!               t
!             ]
!           if
!         ]
!         loop
        
!       ]
!     ]
!     with-monitors
!   ]
!   in-thread ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: start-remotes-monitor-thread ( GADGET -- )

  GADGET f >>closed drop

  [
    [
      [let | MONITOR [ GADGET repository>> t <monitor> ] |
        
        [
          GADGET closed>>
            [ f ]
            [
              [let | PATH [ MONITOR next-change drop ] |

!                 "COMMIT_EDITMSG" PATH subseq?
!                   [ GADGET refresh-git-remotes-gadget ]
!                 when

!                 PATH ".git/refs/heads/master" tail?
!                   [ GADGET refresh-git-remotes-gadget ]
!                 when

                {
                  [ ".git" PATH subseq? ]
                  [ PATH "master" tail? ]
                } 0&&
                  [ GADGET refresh-git-remotes-gadget ]
                when
                

                ]
              t
            ]
          if
        ]
        loop
        
      ]
    ]
    with-monitors
  ]
  in-thread ;




! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: <git-remotes-gadget> graft*   ( gadget -- ) start-remotes-monitor-thread ;
M: <git-remotes-gadget> ungraft* ( gadget -- ) t >>closed drop              ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! git-tool
! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

TUPLE: <git-tool> < pack ;


! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

M: <git-tool> pref-dim* ( gadget -- dim ) drop { 600 500 } ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

:: git-tool ( REPO -- )

  [let | REPO [ REPO [ current-directory get ] with-directory ] |

    <git-tool> new-gadget

    { 0 1 } >>orientation

    1 >>fill

    { 1 0 } <track>
    "Repository: " <label> 1/5 track-add
    REPO [ current-directory get ] with-directory <label> 1 track-add
    add-gadget

    { 1 0 } <track>
    "Branch: " <label> 1/5 track-add
    REPO current-branch <label> 1 track-add
    add-gadget
    
    REPO git-status-gadget add-gadget

    dup "git-tool" open-window

    REPO git-remotes-gadget add-gadget

    drop ] ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

: factor-git-tool ( -- ) "resource:" git-tool ;

! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MAIN: factor-git-tool