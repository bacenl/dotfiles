function squash_headers -d "Consolidate markdown headers with the same name"
    # Check arguments
    if test (count $argv) -ne 1
        echo "Usage: squash_headers <input_file.md>"
        return 1
    end

    set input_file $argv[1]
    set output_file "output_"$input_file

    # Check if input file exists
    if not test -f $input_file
        echo "Error: Input file '$input_file' not found"
        return 1
    end

    # Use Python with a proper tree structure
    python3 -c '
import sys

class Node:
    """Tree node representing a markdown header"""
    def __init__(self, text, parent=None):
        self.text = text            # Header text
        self.parent = parent        # Parent node
        self.children = {}          # Dict of child nodes: {text: Node}
        self.content = []           # Content lines under this header
    
    def add_child(self, text):
        """Add or get a child node"""
        if text not in self.children:
            self.children[text] = Node(text, parent=self)
        return self.children[text]
    
    def add_content(self, line):
        """Add a content line to this node"""
        self.content.append(line)
    
    def get_or_create_path(self, path):
        """Navigate or create a path in the tree. path is a list of header texts"""
        current = self
        for text in path:
            current = current.add_child(text)
        return current
    
    def get_depth(self):
        """Calculate depth of this node (root is 0, its children are 1, etc.)"""
        depth = 0
        node = self
        while node.parent is not None:
            depth += 1
            node = node.parent
        return depth
    
    def to_markdown(self, is_first=True):
        """Convert tree to markdown"""
        lines = []
        
        # Write this node'\''s header (if not root)
        if self.parent is not None:  # Not root
            depth = self.get_depth()
            # Add linebreak before header (except for the very first one)
            if not is_first:
                lines.append("\n")
            lines.append("#" * depth + " " + self.text + "\n")
        
        # Write content
        lines.extend(self.content)
        
        # Write children (sorted by text for consistency)
        first_child = True
        for text in sorted(self.children.keys()):
            child_lines = self.children[text].to_markdown(
                is_first=(is_first and first_child and self.parent is None)
            )
            lines.extend(child_lines)
            first_child = False
        
        return lines


def parse_markdown(filename):
    """Parse markdown file and build tree structure"""
    with open(filename, "r") as f:
        lines = f.readlines()
    
    # Root node (invisible)
    root = Node(text="ROOT")
    current_path = []
    
    for line in lines:
        stripped = line.lstrip()
        
        # Check if this is a header
        if stripped.startswith("#"):
            # Count consecutive # symbols from the start
            level = 0
            for char in stripped:
                if char == "#":
                    level += 1
                else:
                    break
            
            # Skip level 1 headers (# 30, # 31, etc.)
            if level == 1:
                current_path = []
                continue
            
            # Extract header text
            header_text = stripped[level:].strip()
            
            # Position in path corresponds to depth in tree
            # ## (level 2) -> position 0, ### (level 3) -> position 1, etc.
            path_position = level - 2
            
            # Trim path to this position and update
            current_path = current_path[:path_position]
            current_path.append(header_text)
        
        elif current_path and line.strip():
            # This is content - add it to the current node
            node = root.get_or_create_path(current_path)
            node.add_content(line)
    
    return root


def main(input_file, output_file):
    """Main function to process markdown file"""
    # Parse input file into tree
    root = parse_markdown(input_file)
    
    # Convert tree back to markdown
    output_lines = root.to_markdown()
    
    # Write output file
    with open(output_file, "w") as f:
        f.writelines(output_lines)
    
    print(f"Successfully consolidated headers from '\''{input_file}'\'' to '\''{output_file}'\''")


# Run main
if __name__ == "__main__":
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    main(input_file, output_file)

' "$input_file" "$output_file"

end
