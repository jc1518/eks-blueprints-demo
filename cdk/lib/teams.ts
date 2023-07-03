import * as iam from "aws-cdk-lib/aws-iam";
import * as blueprints from "@aws-quickstart/eks-blueprints";

export class TeamPlatform extends blueprints.PlatformTeam {
  constructor(teamName: string, teamRoleArn: string) {
    super({
      name: teamName,
      userRoleArn: teamRoleArn,
    });
  }
}

export class TeamApplication extends blueprints.ApplicationTeam {
  constructor(teamName: string, teamRoleArn: string, teamManifestDir: string) {
    super({
      name: teamName,
      userRoleArn: teamRoleArn,
      teamManifestDir: teamManifestDir,
    });
  }
}
