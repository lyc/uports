# Normalize GitHub declarations into ordered group|account|project|tag|subdir
# records. No filesystem or network access; whitespace/pipe cannot occur in
# validated fields. DEFAULT always describes inheritance, even with nodefault.
function die(message) { problem=message; exit 1 }
function group_ok(g) {
    if (g !~ /^[A-Za-z0-9_]+$/ || g ~ /^(all|ALL|default)$/)
        die("invalid or reserved GitHub group: " g)
}
function remember(g) {
    group_ok(g)
    if (!(g in seen)) { seen[g]=1; groups[++count]=g }
}
function put(field,value,list, n,parts,i) {
    if (list=="") list="DEFAULT"
    n=split(list,parts,",")
    for (i=1;i<=n;i++) {
        remember(parts[i]); values[field,parts[i]]=value
    }
}
function declarations(field,text, n,entries,i,m,p) {
    n=split(text,entries," ")
    for (i=1;i<=n;i++) {
        m=split(entries[i],p,":")
        if (m>2) die("invalid " field " declaration")
        put(field,p[1],m==2 ? p[2] : "DEFAULT")
    }
}
BEGIN {
    remember("DEFAULT")
    values["account","DEFAULT"]=ENVIRON["gh_portname"]
    values["project","DEFAULT"]=ENVIRON["gh_portname"]
    values["tag","DEFAULT"]=ENVIRON["gh_distversion"]
    declarations("account",ENVIRON["gh_account"])
    declarations("project",ENVIRON["gh_project"])
    declarations("tag",ENVIRON["gh_tag"])
    declarations("subdir",ENVIRON["gh_subdir"])
    n=split(ENVIRON["gh_tuple"],tuples," ")
    for (i=1;i<=n;i++) {
        m=split(tuples[i],p,":")
        if (m!=3 && m!=4) die("GH_TUPLE needs account:project:tag[:group][/subdir]")
        list="DEFAULT"; path=""
        if (m==4) {
            slash=index(p[4],"/")
            list=(slash ? substr(p[4],1,slash-1) : p[4])
            if (slash) path=substr(p[4],slash+1)
        }
        put("account",p[1],list); put("project",p[2],list)
        put("tag",p[3],list)
        if (m==4 && slash) put("subdir",path,list)
    }
}
END {
    if (problem!="") {print "ERROR|" problem; exit 1}
    for (i=1;i<=count;i++) {
        g=groups[i]
        a=(("account",g) in values ? values["account",g] : values["account","DEFAULT"])
        proj=(("project",g) in values ? values["project",g] : values["project","DEFAULT"])
        t=(("tag",g) in values ? values["tag",g] : values["tag","DEFAULT"])
        # Placement is never inherited: only account/project/tag share defaults.
        d=values["subdir",g]
        if (a !~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/ ||
            proj !~ /^[A-Za-z0-9_][A-Za-z0-9_.-]*$/)
            {print "ERROR|invalid account/project in group " g; exit 1}
        if (t !~ /^[A-Za-z0-9_.\/+-]+$/ || t !~ /^[A-Za-z0-9_]/ ||
            t ~ /^(master|main|HEAD)$/ || t ~ /^refs\/heads\//)
            {print "ERROR|invalid or moving tag in group " g; exit 1}
        if (d!="") {
            # Inline validation here: die() from END must print its diagnostic.
            if (d !~ /^[A-Za-z0-9_.+\/-]+$/ || d ~ /^[-\/]/ ||
                d ~ /(^|\/)(\.\.?)?(\/|$)/)
                {print "ERROR|unsafe GH_SUBDIR in group " g; exit 1}
        }
        if (g!="DEFAULT" || ENVIRON["gh_nodefault"]=="") {
            ext=t; gsub(/\//,"-",ext)
            if (ext ~ /^[vV][0-9]/) ext=substr(ext,2)
            gsub(/\+/,"-",ext); gsub(/--*/,"-",ext)
            root=proj "-" ext; identity=a "|" proj "|" t
            if (root in owners && (owners[root]!=identity ||
                destinations[root]!=d || owner_group[root]=="DEFAULT")) {
                print "ERROR|GitHub archive extraction roots collide: " root
                exit 1
            }
            owners[root]=identity; destinations[root]=d; owner_group[root]=g
        }
        printf "%s|%s|%s|%s|%s\n",g,a,proj,t,(d=="" ? "-" : d)
    }
}
