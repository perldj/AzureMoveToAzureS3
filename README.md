# AzureMoveToAzureS3
A script for current customers who are using minion to move them from using Azure/Minio to pure Azure to store attachments

This script is loosely based on this script here https://bitbucket.org/marvalsoftware/aws-scripts/src/master/Migration/.

Previously, Marval did not surpport Azure attachmnets so we started using a program called Minio to store attachments in Azure and translate them using Minio, which allowed us to use an 'S3 endpoint' pointing to Minio, which would then translate these attachments into Azure.
This is no longer required and we are able to use Azure natively from Marval.
In addition to the new support, Minio no longer supports Azure, so we are on an old unsupported version of Minio.

  
To configure Marval to use Azure, you use the following format.
DefaultEndpointsProtocol=https;AccountName=_accountname_;AccountKey=_accountkey_;EndpointSuffix=core.windows.net

 _accountname_ is the Storage Account Name<br> _accountkey_ is the Storage Account Access key

 The other required item is Container Name, this is normally msm, however it may not be and is accessed by navigating to your Container, navigating to Containers under Data storage. The Container Name will then be listed there.

