# AzureMoveToAzureS3
A script for current customers who are moving from using Azure/Minio to pure Azure to store attachments

This script is loosely based on this script here https://bitbucket.org/marvalsoftware/aws-scripts/src/master/Migration/.

Previously, Marval did not surpport Azure attachmnets so we started using a program called Minio to store attachments in Azure and translate them using Minio, which allowed us to use an 'S3 endpoint' pointing to Minio, which would then translate these attachments into Azure.
This is no longer required and we are able to use Azure natively from Marval.
In addition to the new support, Minio no longer supports Azure, so we are on an old unsupported version of Minio.

  
