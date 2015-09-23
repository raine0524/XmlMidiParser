#include "ParseExport.h"

int NumericEnding::getJumpCount()
{
	if (jumpCount)
		return jumpCount;

	int count = 0;
	int len = strlen(numeric_text.c_str());
	if (len > 0)
	{
		int items_count = 0;
		int numbers[16];
		memset(numbers, 0, sizeof(numbers));
		for (int i = 0; i < len; i++)
		{
			char ch = numeric_text[i];
			if (ch >= '0' && ch <= '9') {
				numbers[items_count] *= 10;
				numbers[items_count] += ch-'0';
			} else {
				numbers[items_count] -= 1;
				items_count++;
			}
		}

		for (int i = 0; i < items_count; i++)
		{
			int num = numbers[i];
			if (i+1 != num)
				break;
			count = i+1;
		}
	}
	jumpCount = count;
	return count;
}

void OveMeasure::checkDontPlayedNotes()
{
	//remove notes, which has smaller duration with same tone
	for (auto it = sorted_notes.begin(); it != sorted_notes.end(); it++)
	{
		auto& notes = it->second;
		for (auto note = notes.begin(); note != notes.end(); note++)
		{
			if ((*note)->isGrace)
				continue;
			//check if there is another longer note with same tone
			for (auto elem = (*note)->note_elems.begin(); elem != (*note)->note_elems.end(); elem++)
			{
				auto tmpNote = notes.begin();
				for (int t = 0; t < notes.size() && !(*elem)->dontPlay; t++, tmpNote++)
				{
					if ((*tmpNote)->isGrace)
						continue;
					if ((*tmpNote)->note_type >= (*note)->note_type && !(*elem)->dontPlay && tmpNote->get() != note->get()) {
						for (auto tmpElem = (*tmpNote)->note_elems.begin(); tmpElem != (*tmpNote)->note_elems.end(); tmpElem++) {
							if ((*tmpElem)->note == (*elem)->note && tmpElem->get() != elem->get() && !(Tie_RightEnd & (*elem)->tie_pos)) {
								(*tmpElem)->dontPlay = true;
								if ((*tmpElem)->xml_finger != "" && (*elem)->xml_finger == "")
									(*elem)->xml_finger = (*tmpElem)->xml_finger;
								break;
							}
						}
					}
				}
			}
		}
	}

	for (auto it = sorted_notes.begin(); it != sorted_notes.end(); it++)
	{
		auto& notes = it->second;
		for (auto note = notes.begin(); note != notes.end(); note++)
		{
			//check if there is another longer note with same tone
			int dontPlayElems = 0;
			for (auto elem = (*note)->note_elems.begin(); elem != (*note)->note_elems.end(); elem++)
				if ((*elem)->dontPlay)
					dontPlayElems++;

			if (dontPlayElems > 0 && dontPlayElems == (*note)->note_elems.size())
				(*note)->dontPlay = true;
		}
	}
}