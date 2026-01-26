export interface Mod {
  id: string;
  fileName: string;
  enabled: boolean;
  filePath: string;
  name?: string;
  version?: string;
  description?: string;
  author?: string;
  manual?: boolean;
}
