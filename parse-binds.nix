{lib, ...}:
with lib; let
  short-circuit = v: steps:
    pipe v (map (step: x:
      if x == null
      then null
      else step x)
    steps);

  coalesce = flip pipe [
    (remove null)
    head
  ];

  ifilter = f:
    flip pipe [
      (imap0 (i: v: {inherit i v;}))
      (filter ({i, ...}: f i))
      (map ({v, ...}: v))
    ];

  filter-prev = f: l:
    if l == []
    then []
    else [(head l)] ++ (ifilter (flip pipe [(elemAt l) f]) (tail l));

  kebaberize = flip pipe [
    (replaceStrings strings.upperChars (map (c: "-${c}") strings.lowerChars))
    (removePrefix "-")
  ];
in
  flip short-circuit [
    (src: "${src}/niri-config/src/lib.rs")
    (path:
      if builtins.pathExists path
      then path
      else null)
    builtins.readFile
    (strings.splitString "\n")
    (lists.foldl (
        {
          state,
          actions,
        }: line:
          {
            leading = {
              state =
                if line == "pub enum Action {"
                then "actions"
                else "leading";
              inherit actions;
            };
            actions =
              if line == "}"
              then {
                state = "trailing";
                inherit actions;
              }
              else {
                state = "actions";
                actions = actions ++ [line];
              };
            trailing = {
              state = "trailing";
              inherit actions;
            };
          }
          .${
            state
          }
      ) {
        state = "leading";
        actions = [];
      })
    ({
      state,
      actions,
    }:
      assert (state == "trailing"); actions)
    (remove "")
    (map (removePrefix "    "))
    (filter-prev (prev: prev != "#[knuffel(skip)]"))
    (remove "#[knuffel(skip)]")
    # Handle multi-line and single-line actions
    (map (line: 
      let
        singleLineMatch = strings.match ''([A-Za-z]*),'' line;
        paramLineMatch = strings.match ''([A-Za-z]*)\(.*\),'' line;
        multiLineStartMatch = strings.match ''([A-Za-z]*)\('' line;
        
        raw-name = 
          if singleLineMatch != null then elemAt singleLineMatch 0
          else if paramLineMatch != null then elemAt paramLineMatch 0
          else if multiLineStartMatch != null then elemAt multiLineStartMatch 0
          else null;
          
        name = if raw-name != null then kebaberize raw-name else null;
      in
        if name != null then { inherit name; } else null
    ))
    (remove null)
  ]
