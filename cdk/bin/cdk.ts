#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as eks from "aws-cdk-lib/aws-eks";
import * as iam from "aws-cdk-lib/aws-iam";
import * as blueprints from "@aws-quickstart/eks-blueprints";
import { KubernetesVersion } from "aws-cdk-lib/aws-eks";
import { DemoVpcProps, DemoVpcResourceProvider } from "../lib/vpc";
import { TeamPlatform, TeamApplication } from "../lib/teams";

const app = new cdk.App();

const account = process.env.CDK_DEFAULT_ACCOUNT;
const region = process.env.CDK_DEFAULT_REGION;

const name = "eks-blueprints-cdk";

// Demo VPC
const demoVpcInfo: DemoVpcProps = {
  vpcName: `${name}-vpc`,
  vpcCidr: "10.1.0.0/16",
  maxAzs: 3,
  natGateways: 1,
};
const demoVpcProvider = new DemoVpcResourceProvider(demoVpcInfo);

// Demo EKS cluster
const masterRoleName = "AWSReservedSSO_AWSAdministratorAccess_7e5d8ea1712c4547";
const demoClusterProvider = new blueprints.GenericClusterProvider({
  version: KubernetesVersion.V1_26,
  mastersRole: blueprints.getResource((context) => {
    return iam.Role.fromRoleName(
      context.scope,
      "ClusterAdminRole",
      masterRoleName
    );
  }),
  managedNodeGroups: [
    {
      id: "eks-managed",
      amiType: eks.NodegroupAmiType.AL2_X86_64,
      instanceTypes: [new ec2.InstanceType("t3.medium")],
      nodeGroupCapacityType: eks.CapacityType.SPOT,
    },
  ],
  fargateProfiles: {
    fargate: {
      fargateProfileName: "karpenter",
      selectors: [{ namespace: "karpenter" }],
    },
  },
  tags: {
    Name: name,
  },
});

// Add-ons
const addOns: Array<blueprints.ClusterAddOn> = [
  new blueprints.addons.VpcCniAddOn(),
  new blueprints.addons.EbsCsiDriverAddOn(),
  new blueprints.addons.KubeProxyAddOn("v1.26.2-eksbuild.1"),
  new blueprints.addons.CoreDnsAddOn("v1.9.3-eksbuild.2"),
];

// Teams
// Platform team
const platformTeamRoleName =
  "AWSReservedSSO_AWSAdministratorAccess_7e5d8ea1712c4547";
const teamPlatformRole = blueprints.getResource((context) => {
  return iam.Role.fromRoleName(
    context.scope,
    "PlatformTeamRole",
    platformTeamRoleName
  );
});
const teamPlatform = new TeamPlatform("platform", teamPlatformRole.roleArn);

// Application team
const appliationTeamRoleName =
  "AWSReservedSSO_AWSDeveloperAccess_908d308ffbc9dd79";
const applicationPlatformRole = blueprints.getResource((context) => {
  return iam.Role.fromRoleName(
    context.scope,
    "ApplicationTeamRole",
    appliationTeamRoleName
  );
});
const teamApplication = new TeamApplication(
  "application",
  applicationPlatformRole.roleArn,
  "./manifest/team-application/"
);

// EKS Blueprints stacks
blueprints.EksBlueprint.builder()
  .account(account)
  .region(region)
  .resourceProvider(blueprints.GlobalResources.Vpc, demoVpcProvider)
  .clusterProvider(demoClusterProvider)
  .addOns(...addOns)
  .teams(teamPlatform)
  .teams(teamApplication)
  .build(app, name);
