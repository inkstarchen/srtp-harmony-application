export interface ToolBarButtonParams {
  icon: Resource;
  action: () => void;
}

export interface ToolBarButtonStateParams extends ToolBarButtonParams {
  isActive?: boolean;
}

export interface ColorButtonParams {
  color: Color;
  action: () => void;
}

export interface DropdownButtonParams {
  isOpen: boolean;
  action: () => void;
}

export interface ColorSwatchParams {
  color: Color;
  action: () => void;
}