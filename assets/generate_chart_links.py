from pathlib import Path

def generate_chart_links():
    # Define the directory and GitHub base URL
    charts_dir = Path("charts")
    base_url = "https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/charts/"
    
    # Supported image formats
    image_extensions = {".png", ".jpg", ".jpeg", ".svg", ".gif", ".webp"}
    
    if not charts_dir.exists() or not charts_dir.is_dir():
        print(f"Error: The directory '{charts_dir}' was not found.")
        return

    print("Generated Markdown Links:\n")
    
    # Iterate through files in the charts directory alphabetically
    for file_path in sorted(charts_dir.iterdir()):
        if file_path.suffix.lower() in image_extensions:
            filename = file_path.name
            
            # Generate a clean alt text from the filename (e.g., 'customer-age-distribution' -> 'Customer Age Distribution')
            alt_text = file_path.stem.replace("-", " ").replace("_", " ").title()
            
            # Construct and print the markdown link
            markdown_link = f"![{alt_text}]({base_url}{filename})"
            print(markdown_link)

if __name__ == "__main__":
    generate_chart_links()