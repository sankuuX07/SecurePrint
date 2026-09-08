def parse_page_range(page_range: str, total_pages: int) -> int:
    """
    Parses a page range string and returns the number of selected pages.
    Valid formats: '1', '1-3', '1,3,5-7', '1-3,7-9'
    Raises ValueError if the range is invalid or exceeds total_pages.
    """
    if not page_range:
        return total_pages
        
    page_range = page_range.replace(" ", "")
    selected_pages = set()
    
    parts = page_range.split(",")
    for part in parts:
        if "-" in part:
            bounds = part.split("-")
            if len(bounds) != 2:
                raise ValueError(f"Invalid range format: {part}")
            
            try:
                start = int(bounds[0])
                end = int(bounds[1])
            except ValueError:
                raise ValueError(f"Invalid range format, numbers expected: {part}")
                
            if start < 1 or end < start:
                raise ValueError(f"Invalid range: {part}")
                
            if end > total_pages:
                raise ValueError(f"Page range exceeds total pages ({total_pages})")
                
            for p in range(start, end + 1):
                selected_pages.add(p)
        else:
            try:
                page_num = int(part)
            except ValueError:
                raise ValueError(f"Invalid page number: {part}")
                
            if page_num < 1:
                raise ValueError(f"Invalid page number: {page_num}")
                
            if page_num > total_pages:
                raise ValueError(f"Page number {page_num} exceeds total pages ({total_pages})")
                
            selected_pages.add(page_num)
            
    return len(selected_pages)
