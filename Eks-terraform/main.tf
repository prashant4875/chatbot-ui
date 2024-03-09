data "aws_iam_policy_document" "assume_role1" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example1" {
  name               = "eks-cluster-example"
  assume_role_policy = data.aws_iam_policy_document.assume_role1.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example1.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example1.name
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
    filter {
      name = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
}

resource "aws_eks_cluster" "example" {
  name = "EKS_OpenAI"
  role_arn = aws_iam_role.example1.arn
  vpc_config {
    subnet_ids = slice(data.aws_subnets.public.ids, 0, 3) 
  }

  depends_on = [ 
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy1,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController1
   ]
}

resource "aws_iam_role" "ec2Role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Statement = [{
        Action = "sts:AssumeRole"
        Effect: "Allow"
        Principal = {
            Service = "ec2.amazonaws.com"
        }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ec2Role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ec2Role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ec2Role.name
}

resource "aws_eks_node_group" "EKS-NodeGroup" {
  cluster_name = aws_eks_cluster.example.name
  node_group_name = "eksNodeGroup"
  node_role_arn = aws_iam_role.ec2Role.arn
  subnet_ids = slice(data.aws_subnets.public.ids, 0, 3)

  instance_types = ["t2.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}