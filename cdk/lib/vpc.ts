import {
  ResourceContext,
  ResourceProvider,
} from "@aws-quickstart/eks-blueprints";
import * as ec2 from "aws-cdk-lib/aws-ec2";

export interface DemoVpcProps {
  vpcName: string;
  vpcCidr: string;
  maxAzs: number;
  natGateways: number;
}

export class DemoVpcResourceProvider implements ResourceProvider<ec2.IVpc> {
  readonly vpcName: string;
  readonly vpcCidr: string;
  readonly maxAzs: number;
  readonly natGateways: number;

  constructor(vpcProps: DemoVpcProps) {
    this.vpcName = vpcProps.vpcName;
    this.vpcCidr = vpcProps.vpcCidr;
    this.maxAzs = vpcProps.maxAzs;
    this.natGateways = vpcProps.natGateways;
  }

  provide(context: ResourceContext): ec2.IVpc {
    const vpc = new ec2.Vpc(context.scope, this.vpcName, {
      vpcName: this.vpcName,
      ipAddresses: ec2.IpAddresses.cidr(this.vpcCidr),
      maxAzs: this.maxAzs,
      natGateways: this.natGateways,

      subnetConfiguration: [
        {
          cidrMask: 24,
          name: "public",
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 20,
          name: "private",
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
    });

    return vpc;
  }
}
