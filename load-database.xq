xquery version "3.1";
(: part of Guid-O-Matic 2.0 https://github.com/baskaufs/guid-o-matic . You are welcome to reuse or hack in any way :)

(: The earlier version of this (no HTTP support) is now called load-database-old.xq :)

(: Note: output of the XML files is to the directory specified in the constants.csv file in the input directory :)

(: It is important that the column headers in linked CSV data files are unique. :)

(: In order to avoid hard-coding file locations, the propvalue module is imported from GitHub.  It is unlikely that you will need to modify any of the functions it contains, but if you do, you will need to substitute after the "at" keyword the path to the local directory where you put the propvalue.xqm file :)
import module namespace propvalue = 'http://bioimages.vanderbilt.edu/xqm/propvalue' at 'https://raw.githubusercontent.com/baskaufs/guid-o-matic/master/propvalue.xqm'; 


(: These two functions copied from FunctX http://www.xqueryfunctions.com/ :)

declare function local:substring-after-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   replace ($arg,concat('^.*',local:escape-for-regex($delim)),'')
 } ;
 
 declare function local:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;
(:--------------------------------------------------------------------------------------------------:)

declare function local:main($repoLocation,$repoPath,$dbaseName,$outputMethod,$password)
{

(: This is an attempt to allow the necessary CSV files to load on any platform without hard-coding any paths here.  I know it works for PCs, but am not sure how consistently it works on non-PCs :)
let $localFilesFolderUnix := "file:///"||$repoLocation||$repoPath||$dbaseName||"/"
    
let $constantsDoc := file:read-text(concat($localFilesFolderUnix, 'constants.csv'))
let $xmlConstants := csv:parse($constantsDoc, map { 'header' : true(),'separator' : "," })
let $constants := $xmlConstants/csv/record

let $domainRoot := $constants//domainRoot/text()
let $coreDoc := $constants//coreClassFile/text()
let $coreClassPrefix := substring-before($coreDoc,".")
(: let $outputDirectory := "c:/test/output/xml/"   :)
let $outputDirectory := $constants//outputDirectory/text()
let $metadataSeparator := $constants//separator/text()
let $baseIriColumn := $constants//baseIriColumn/text()
let $modifiedColumn := $constants//modifiedColumn/text()
let $outFileNameAfter := $constants//outFileNameAfter/text()

let $columnIndexDoc := file:read-text($localFilesFolderUnix||$coreClassPrefix||'-column-mappings.csv')
let $xmlColumnIndex := csv:parse($columnIndexDoc, map { 'header' : true(),'separator' : "," })
let $columnInfo := $xmlColumnIndex/csv/record

let $namespaceDoc := file:read-text(concat($localFilesFolderUnix,'namespace.csv'))
let $xmlNamespace := csv:parse($namespaceDoc, map { 'header' : true(),'separator' : "," })
let $namespaces := $xmlNamespace/csv/record

let $classesDoc := file:read-text($localFilesFolderUnix||$coreClassPrefix||'-classes.csv')
let $xmlClasses := csv:parse($classesDoc, map { 'header' : true(),'separator' : "," })
let $classes := $xmlClasses/csv/record

let $linkedClassesDoc := file:read-text(concat($localFilesFolderUnix,'linked-classes.csv'))
let $xmlLinkedClasses := csv:parse($linkedClassesDoc, map { 'header' : true(),'separator' : "," })
let $linkedClasses := $xmlLinkedClasses/csv/record

let $metadataDoc := file:read-text($localFilesFolderUnix ||$coreDoc)
let $xmlMetadata := csv:parse($metadataDoc, map { 'header' : true(),'separator' : $metadataSeparator })
let $metadata := $xmlMetadata/csv/record

let $linkedMetadata :=
      for $class in $linkedClasses
      let $linkedDoc := $class/filename/text()
      let $linkedClassPrefix := substring-before($linkedDoc,".")

      let $classMappingDoc := file:read-text(concat($localFilesFolderUnix,$linkedClassPrefix,"-column-mappings.csv"))
      let $xmlClassMapping := csv:parse($classMappingDoc, map { 'header' : true(),'separator' : "," })
      let $classClassesDoc := file:read-text(concat($localFilesFolderUnix,$linkedClassPrefix,"-classes.csv"))
      let $xmlClassClasses := csv:parse($classClassesDoc, map { 'header' : true(),'separator' : "," })
      let $classMetadataDoc := file:read-text(concat($localFilesFolderUnix,$linkedDoc))
      let $xmlClassMetadata := csv:parse($classMetadataDoc, map { 'header' : true(),'separator' : $metadataSeparator })
      return
        ( 
        <file>{
          $class/link_column,
          $class/link_property,
          $class/suffix1,
          $class/link_characters,
          $class/suffix2,
          $class/class,
          <classes>{
            $xmlClassClasses/csv/record
          }</classes>,
          <mapping>{
            $xmlClassMapping/csv/record
          }</mapping>,
          <metadata>{
            $xmlClassMetadata/csv/record
          }</metadata>
       }</file>
       )
return (
  (:  file:write-text("c:\Dropbox\swwg\manage-databases\upload-log.txt", :)
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"constants.xml",<constants>{$constants}</constants>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"column-index.xml",<column-index>{$columnInfo}</column-index>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"namespaces.xml",<namespaces>{$namespaces}</namespaces>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"classes.xml",<base-classes>{$classes}</base-classes>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"linked-classes.xml",<linked-classes>{$linkedClasses}</linked-classes>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"metadata.xml",<metadata>{$metadata}</metadata>),
    local:output($outputMethod,$outputDirectory,$dbaseName,$password,"linked-metadata.xml",<linked-metadata>{$linkedMetadata}</linked-metadata>)
    )
};

declare function local:output($outputMethod,$outputDirectory,$dbaseName,$password,$fileName,$outputXml)
{
  if ($outputMethod="file")
  then 
    local:write-file-local($outputDirectory,$fileName,$outputXml)
  else
    if ($outputMethod="screen")
    then
      $outputXml (: simply output the string to the Result window :)
    else 
      local:write-file-http($outputMethod||$dbaseName||'/',$password,$fileName,$outputXml) (: $outputMethod contains base URI for the REST service for the PUT; the database name gets concatenated after that :)
};

declare function local:write-file-local($outputDirectory,$fileName,$outputXml)
{ 
(: Creates the specified output directory if it doesn't already exist.  Then writes into a file using default UTF-8 encoding :)
file:create-dir($outputDirectory),file:write($outputDirectory||$fileName,$outputXml),
"Completed file write of "||$fileName||" at "||fn:current-dateTime()
};

declare function local:write-file-http($URI,$password,$fileName,$outputXml)
{ 
let $request :=
  <http:request href='{concat($URI,$fileName)}'
    method='put' username='admin' password='{$password}' send-authorization='true'>
      <http:body media-type='application/xml'>
        {$outputXml}
      </http:body>
  </http:request>
return concat($fileName," ",string-join(http:send-request($request)))
};

(:--------------------------------------------------------------------------------------------------:)
(: Here's the main query that makes it go :)

(: Find the github repo home by getting the parent directory  :)
let $gitRepoWin := file:parent(file:base-dir())

(: If it's a Windows file system, replace backslashes with forward slashes.  Otherwise, nothing happens. :)
let $gitRepo := fn:replace($gitRepoWin,"\\","/")
(:  let $gitRepo := "c:/github/"  :)

(: 
1st argument is the root path of the github repo, determined automatically if running from Guid-O-Matic repo (I hope; ignore if using HTTP)
2nd argument is the path from the github repo to the repo in which the CSV files are saved (ignore if using HTTP)
3rd arugment is the database name as used in restxq.xqm; must also be the subfolder name of the github repo in which the CSV files are saved
4th argument is the output method: "file", "screen", or a URI for HTTP PUT to the BaseX REST API e.g. http://localhost:8984/rest/ for a local installation, or an Internet URI for the cloud.
5th argument is the password for communicating with the BaseX REST API (ignore if not using HTTP)
:)
return local:main($gitRepo,"semantic-web/2016-fall/","building","screen","pwd")
