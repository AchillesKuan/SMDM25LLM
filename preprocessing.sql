/****************************************************************/
use XXXX ---target database
GO

/****************************************************************

Analytic cohort

****************************************************************/
Drop Table If Exists #analyticcohort;
select ID, min(searchstart) as firststart, max(searchend) as lastend
into #CohortForNextStep
from XXXX ---target dataset
group by ID
;


/****************************************************************

Search for sMM keywords within the notes

****************************************************************/
DECLARE @ContainsText varchar(4000);

SET @ContainsText =
	'NEAR((smoldering, myeloma), 5, TRUE) OR NEAR((smoldering, mm), 5, TRUE) OR NEAR((smoldering, myleoma), 5, TRUE) OR NEAR((smoldering, meyloma), 5, TRUE) 
	OR NEAR((smouldering, myeloma), 5, TRUE) OR NEAR((smouldering, mm), 5, TRUE) OR NEAR((smouldering, myleoma), 5, TRUE) OR NEAR((smouldering, meyloma), 5, TRUE) 
	OR NEAR((smoulderind, myeloma), 5, TRUE) OR NEAR((smoulderind, mm), 5, TRUE) OR NEAR((smoulderind, myleoma), 5, TRUE) OR NEAR((smoulderind, meyloma), 5, TRUE)  
	OR NEAR((somldering, myeloma), 5, TRUE) OR NEAR((somldering, mm), 5, TRUE) OR NEAR((somldering, myleoma), 5, TRUE) OR NEAR((somldering, meyloma), 5, TRUE)  
	OR NEAR((smouldiner, myeloma), 5, TRUE) OR NEAR((smouldiner, mm), 5, TRUE) OR NEAR((smouldiner, myleoma), 5, TRUE) OR NEAR((smouldiner, meyloma), 5, TRUE)  
	OR NEAR((smolerding, myeloma), 5, TRUE) OR NEAR((smolerding, mm), 5, TRUE) OR NEAR((smolerding, myleoma), 5, TRUE) OR NEAR((smolerding, meyloma), 5, TRUE)  
	OR NEAR((smolding, myeloma), 5, TRUE) OR NEAR((smolding, mm), 5, TRUE) OR NEAR((smolding, myleoma), 5, TRUE) OR NEAR((smolding, meyloma), 5, TRUE)  
	OR NEAR((smolderimg, myeloma), 5, TRUE) OR NEAR((smolderimg, mm), 5, TRUE) OR NEAR((smolderimg, myleoma), 5, TRUE) OR NEAR((smolderimg, meyloma), 5, TRUE)  
	OR NEAR((smolderin, myeloma), 5, TRUE) OR NEAR((smolderin, mm), 5, TRUE) OR NEAR((smolderin, myleoma), 5, TRUE) OR NEAR((smolderin, meyloma), 5, TRUE)  
	OR NEAR((indolent, myeloma), 5, TRUE) OR NEAR((indolent, mm), 5, TRUE) OR NEAR((indolent, myleoma), 5, TRUE) OR NEAR((indolent, meyloma), 5, TRUE) 
	OR NEAR((somldering, myeloma), 5, TRUE) OR NEAR((somldering, mm), 5, TRUE) OR NEAR((somldering, myleoma), 5, TRUE) OR NEAR((somldering, meyloma), 5, TRUE)
	OR NEAR((asymptomatic, myeloma), 5, TRUE) OR NEAR((asymptomatic, mm), 5, TRUE) OR NEAR((asymptomatic, myleoma), 5, TRUE) OR NEAR((asymptomatic, meyloma), 5, TRUE)
	OR "smm"'	
;

DROP TABLE IF EXISTS #TIU_Documents_XXX; 

SELECT DISTINCT
		TIUSearchRank      -- relevance score
		,TIUDocumentSID
	INTO
		#TIU_Documents_XXX
	FROM 
		Src.tvf_TIU_FullTextSearch(@ContainsText)
;

--	To get note definition associated with each note

DROP TABLE IF EXISTS #TIU_Patients_XXX;

SELECT 
		COH.ID
		,TIU_1.TIUDocumentSID
		,convert(date, TIU_1.EntryDateTime) as TIU_Date
		,CASE 
			WHEN TIU_1.ParentTIUDocumentSID = -1 THEN DEFS_1.TIUDocumentDefinition 
			ELSE  DEFS_2.TIUDocumentDefinition 
			END AS ActualTIUDocumentDefinition
		,CASE 
			WHEN TIU_1.ParentTIUDocumentSID = -1 THEN title1.TIUStandardTitle 
			ELSE  TITLE2.TIUStandardTitle 
			END AS ActualTIUStandardTitle
	INTO 
		#TIU_Patients_XXX
	FROM 
		#CohortForNextStep AS COH 
	INNER JOIN
		Src.TIU_TIUDocument AS TIU_1 
		ON		COH.ID = TIU_1.ID
	INNER JOIN 
		#TIU_Documents_XXX AS T
		ON		T.TIUDocumentSID = TIU_1.TIUDocumentSID
	INNER JOIN 
		CDWWork.Dim.TIUDocumentDefinition AS DEFS_1 
		ON		TIU_1.TIUDocumentDefinitionSID = DEFS_1.TIUDocumentDefinitionSID
	INNER JOIN 
		CDWWork.Dim.TIUStandardTitle AS title1 
		on		DEFS_1.TIUStandardTitleSID = title1.TIUStandardTitleSID
	LEFT JOIN  
		Src.TIU_TIUDocument AS TIU_2 
		ON		TIU_1.ParentTIUDocumentSID = TIU_2.TIUDocumentSID
	LEFT JOIN  
		CDWWork.Dim.TIUDocumentDefinition AS DEFS_2 
		ON		TIU_2.TIUDocumentDefinitionSID = DEFS_2.TIUDocumentDefinitionSID
	LEFT JOIN 
		CDWWork.Dim.TIUStandardTitle AS TITLE2 
		ON		DEFS_2.TIUStandardTitleSID = TITLE2.TIUStandardTitleSID
	WHERE 
			convert(date, TIU_1.EntryDateTime) >= coh.firststart
			AND convert(date, TIU_1.EntryDateTime) <= coh.lastend
			AND T.TIUSearchRank > 0	
;

/****************************************************************

An algorithm for selecting hem/onc notes

****************************************************************/
DROP TABLE IF EXISTS Dflt.SMDM2025TIU_Notes_upd2_hemonc;
SELECT 
		COH.ID
		,convert(date, NOTE.EpisodeBeginDateTime) AS EpisodeBeginDate		
		,NOTE.ReportText
	INTO
		XXXX ---location to save selected clinical notes
	FROM 
		#TIU_Patients_XXX AS COH
	INNER JOIN 
		XXXX AS NOTE ---location of clinical notes database
		ON		COH.TIUDocumentSID = NOTE.TIUDocumentSID
	WHERE 
		ActualTIUDocumentDefinition like '%hematology%' 
		OR ActualTIUDocumentDefinition like '%oncology%'
		OR ActualTIUDocumentDefinition like '%cancer%'
		OR (ActualTIUDocumentDefinition like '%hem%' AND ActualTIUDocumentDefinition like '%onc%')
		OR ActualTIUDocumentDefinition in ('C&P FOLLOW UP', 'LR SURGICAL PATHOLOGY REPORT')
		OR ActualTIUStandardTitle like '%hematology%' 
		OR ActualTIUStandardTitle like '%oncology%'
		OR ActualTIUStandardTitle like '%cancer%'
		OR (ActualTIUStandardTitle like '%hem%' AND ActualTIUStandardTitle like '%onc%')
	ORDER BY ID
			,EpisodeBeginDate
;


