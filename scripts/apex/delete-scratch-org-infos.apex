List<ScratchOrgInfo> scratchOrgInfos = [ SELECT Id, ScratchOrg FROM ScratchOrgInfo WHERE Status = 'Deleted' ];

delete scratchOrgInfos;